## Context

`Visit` currently requires `host_person_id` (`NOT NULL`, FK to `people`), validated by `host_active_on_unit` (must have an active `UnitOwnership`/`UnitOccupancy` on the visited unit at visit time — `Visit.host_eligible?`/`active_ownership?`/`active_occupancy?`). The admin form (`admin/visits/new`) has a dedicated host-selection step backed by `Visits::EligibleHosts` (any active owner/occupant, not filtered by `can_authorize_visits`) and `Admin::VisitsController#form_hosts`. The resident private API (`POST /api/v1/private/units/:unit_id/visits`) auto-resolves `host_person_id` from the authenticated resident via `Residents::VisitContext#host_person`.

Independently, `Notifications::CreateForVisit` (from the `add-fcm-push-notifications` change) already resolves who is responsible for a visit via `UnitOccupancy.active_authorizers_for(visit.unit)` — i.e., every active resident with `can_authorize_visits: true` — and this has never depended on `host_person`. The two concepts (host vs. authorizer) can disagree: `Visits::EligibleHosts` includes ANY active owner/occupant regardless of `can_authorize_visits`, so a visit's "host" could be someone who is never actually notified, while the real notified/responsible parties (the authorizers) go unrepresented in the UI.

This change removes `host_person_id` entirely and replaces every UI surface that displayed a single host with a live list of the unit's current active authorizers, aligning the visible "who's responsible" concept with the actual notification/authorization model.

## Goals / Non-Goals

**Goals:**
- Remove `host_person_id` (column, association, validations, related class methods) from `Visit`.
- Remove the host step from `admin/visits/new` and the host param from the resident private API.
- Replace host display in admin/concierge list and detail views with the unit's current active-authorizer list.
- Keep `Notifications::CreateForVisit`/`DeliverPushNotificationJob` untouched — they were never coupled to `host_person`.

**Non-Goals:**
- Changing who gets notified or how (`UnitOccupancy.active_authorizers_for` stays exactly as-is).
- Adding a new `visit_authorizations` or similar join table to record a per-visit snapshot of authorizers — the authorizers list shown is always the *current* live set for the unit, not a historical snapshot at the time the visit was created (see Decision 3).
- Changing the concierge/admin visit list's underlying scoping or authorization rules — only the displayed "host" field is replaced.

## Decisions

1. **Drop `host_person_id` entirely rather than making it nullable.**
   Per product decision, the host concept is removed, not deprecated-but-kept. Migration drops the column (and its index/FK); `Visit` drops `belongs_to :host_person`, the `host_active_on_unit` validation, `host_eligible?`/`active_ownership?`/`active_occupancy?` class methods (used nowhere else), the `validates_same_tenant :host_person` entry, and the `host_person_id`/`host_person` entries in `audited only: [...]`, `ransackable_associations`, `ransackable_attributes`.
   - *Alternative considered*: making the column nullable and unused — rejected per product decision (clean removal, no half-migrated state to reason about later).

2. **`Visits::EligibleHosts` is deleted, not repurposed.**
   Its query (any active owner/occupant, unfiltered by `can_authorize_visits`) doesn't match the authorizers concept needed for display (`UnitOccupancy.active_authorizers_for`, filtered by `can_authorize_visits: true`). Rather than adapt it, admin/concierge views that need the authorizers list call `UnitOccupancy.active_authorizers_for(unit)` directly (already public, already used by `Notifications::CreateForVisit`) — no new service needed for a single-line query reused in a handful of serializers.

3. **The displayed "authorizers" list is always the unit's *current* set, not a snapshot from when the visit was created — and this is fine because "who actually authorized this visit" is already answered by the existing `authorized_by_id`, a different field entirely.**
   Since there is no per-visit host record anymore, admin/concierge serializers compute `unit.unit_occupancies... .active_authorizers_for` at render time from `visit.unit`. This means the list shown for an old visit reflects *today's* authorizers, which may differ from who was an authorizer when the visit was created (occupancy could have changed since). Per product decision, this is explicitly fine: the two questions are distinct and both already have a correct answer —
   - *"Who actually authorized this specific visit?"* → `visit.authorized_by_id` (a `User`, stamped by `Visit::StateMachine#stamp_authorization` at the moment of authorization). This is historical, immutable, and entirely unaffected by this change.
   - *"Who could authorize entry for this unit right now?"* → the live `authorizers` list this change adds to the serializers. This is operational/prospective context (e.g. "who do I call about this unit today"), not a historical record, and is not expected to match `authorized_by_id` for an old visit.
   No snapshot/join table is needed because nothing was actually asking for one — the live list was never meant to answer the historical question, which was already answered elsewhere.
   - *Alternative considered*: snapshotting authorizer person ids onto `Visit` at creation time (e.g., a `metadata` entry) — rejected as unnecessary; it would have duplicated a historical-record concern that `authorized_by_id` (and, since the FCM change, `Notification.recipient_person_id`) already covers.

4. **`Residents::VisitContext::Result` drops `host_person`; `Residents::CreateAuthorizedVisit` no longer accepts or passes `host_person:`/`host_person_id:`.**
   `VisitContext#authorized?` and `#denial_reason` are unaffected — the authorization check for a resident (`create_visits` AND `authorize_visits` on the unit) is identical regardless of the host concept; only the now-unnecessary `host_person` resolution is removed.
   - *Alternative considered*: keeping `VisitContext#host_person` for backward compatibility in case other code reads it — rejected; grep confirms `Residents::CreateAuthorizedVisit` is its only caller, both are updated together in this change.

5. **Admin visit creation form removes the host step outright** — the wizard goes property → unit → visitor → schedule → additional → confirm (host step deleted, not skipped/hidden). `VisitCreateGeneralStep.vue` drops the host searchable-select; `visit_create.ts` drops `host_person_id`/`host_display_name` from `VisitCreateForm` and the Zod schema; `Admin::VisitsController#form_hosts` action and its route are deleted; `visit_params`/`update_params` drop `host_person_id`.

6. **Serializers replace `host`/`host_detail`/`host_person_id` with an `authorizers` array** (list of `{ id, display_name }` for each active `can_authorize_visits` resident of `visit.unit`), across `Admin::VisitSerializer`, `Admin::VisitDetailSerializer`, `Admin::VisitRestrictedSerializer`, `Admin::VisitContextualDetailSerializer`, `Concierge::VisitSerializer`, `Concierge::VisitSummarySerializer`.

## Risks / Trade-offs

- **[Risk] No shared test helper builds `Visit` records — every test file constructs `Visit.create!(..., host_person: ..., ...)` inline.** Confirmed via `grep -rl "host_person" test/`: 24 files reference it, including several completely unrelated to visits as a feature (`property_section_destroy_protection_test.rb`, `units/lifecycle_test.rb`, `units/foundation_coverage_test.rb`, `properties/archive_test.rb`) that only create a `Visit` as incidental setup data. All 24 will raise `ActiveRecord::UnknownAttributeError` once the column is dropped, if left unchanged — this is a mechanical, non-optional part of task 8.1, not an edge case. → Mitigation: task 8.1 enumerates all 24 files explicitly so none are missed. Out of scope for this change, but worth a future follow-up: extracting a shared `create_visit(...)` test helper (mirroring `create_property`/`create_unit` in `OperationalPolicyTestHelper`) would have made this kind of Visit-attribute change touch one place instead of 24.
- **[Risk] Existing production `Visit` rows have a `host_person_id` value that will be discarded on migration.** → Mitigation: this is an intentional, explicit product decision (host concept removed); no data migration is needed to "preserve" host history since the concept itself is being retired. If historical "who was the host" matters later, it remains in any pre-migration DB backup / audit log (`Audited::Audit` rows for `Visit` already captured `host_person_id` changes prior to this change and are not deleted).
- **[Risk] The live authorizers list shown for an old visit can differ from the unit's authorizers at creation time** (Decision 3). → Mitigation: not actually a risk in practice — confirmed by product decision that only `authorized_by_id` (who actually authorized) matters historically, and that field is untouched by this change; the live list was never meant to serve as a historical record.
- **[Risk] `VisitCreatePersonForm`/schema and `Admin::VisitsController#visit_params` changes are a breaking API/param contract change for any external client of these endpoints.** → Mitigation: both are internal-only endpoints (Inertia admin app, private resident mobile API under this org's own control), not a public API — acceptable as a coordinated breaking change with the frontend updated in the same change.
