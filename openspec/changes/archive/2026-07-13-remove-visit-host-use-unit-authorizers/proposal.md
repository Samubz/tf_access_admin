## Why

Every visit today requires a single designated "host" `Person` (`host_person_id`, `NOT NULL`), selected by the operator in `admin/visits/new` or auto-resolved from the authenticated resident in the private API. But the actual notification/authorization responsibility for a visit already belongs collectively to every resident with `can_authorize_visits: true` on the unit (`UnitOccupancy.active_authorizers_for(unit)`) — this is exactly who `Notifications::CreateForVisit` already notifies, independent of who the "host" is. The single-host concept is now redundant with, and inconsistent with, the actual authorization model: a host who happens to lack `can_authorize_visits` never gets notified anyway, while residents who do have it are the ones actually responsible for the visit regardless of who was picked as "host." Removing the host concept eliminates this mismatch and simplifies both visit creation flows.

## What Changes

- **BREAKING**: Remove `host_person_id` from `Visit` entirely (column, `belongs_to :host_person`, `host_active_on_unit` validation, `Visit.host_eligible?`/`active_ownership?`/`active_occupancy?` class methods, `Visits::EligibleHosts` service).
- Remove the host selection step/field from the admin visit creation form (`admin/visits/new`) — property → unit → visitor/schedule/etc., no host step.
- Remove `host_person_id` from the resident private API contract (`POST /api/v1/units/:unit_id/visits`) — no client-supplied or backend-resolved host; `Residents::VisitContext`/`Residents::CreateAuthorizedVisit` no longer reference a host.
- Replace every UI/serializer surface that showed "host" (admin list/detail, concierge list/detail/summary) with the unit's current list of active authorizers (residents with `can_authorize_visits: true`) — labeled "Autorizadores" / "Authorizers", not a single person.
- No change to `Notifications::CreateForVisit` or `DeliverPushNotificationJob` — they already target `UnitOccupancy.active_authorizers_for(unit)`, unaffected by this change.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `visit-management`: removes the host requirement, host form step, host searchable-select behavior, and host-based serializer fields; adds unit-authorizers-list display in their place.
- `residential-visit-management`: removes `host_person_id` from the private API's persisted/derived fields.

## Impact

- **Schema**: migration to drop `visits.host_person_id` (column, index, FK).
- **Models**: `Visit` (remove `belongs_to :host_person`, `host_active_on_unit`, `host_eligible?`, `active_ownership?`, `active_occupancy?`, `ransackable_associations`/`ransackable_attributes` entries, `audited` attribute list entry, `validates_same_tenant` entry).
- **Services removed**: `Visits::EligibleHosts`.
- **Services modified**: `Visits::Create` (no longer accepts/requires `host_person_id`), `Residents::CreateAuthorizedVisit`, `Residents::VisitContext` (no host resolution).
- **Controllers**: `Admin::VisitsController` (`form_hosts` action removed, `visit_params`/`update_params` drop `host_person_id`), `Api::V1::Private::Units::VisitsController`.
- **Serializers**: `Admin::VisitSerializer`, `Admin::VisitDetailSerializer`, `Admin::VisitRestrictedSerializer`, `Admin::VisitContextualDetailSerializer`, `Concierge::VisitSerializer`, `Concierge::VisitSummarySerializer` — replace `host`/`host_detail`/`host_person_id` with an `authorizers` list.
- **Frontend**: `admin/visits/new` wizard (remove host step from `VisitCreateGeneralStep.vue`, `visit_create.ts` schema/types, `useAdminVisitCreate.ts`, `useAdminVisitFormData.ts`), admin/concierge list and detail views (`VisitDetailInfoTab.vue`, `VisitDetailContextualPanel.vue`, `useAdminVisitsList.ts`, index views) swap host display for authorizers list.
- **i18n**: remove host-related keys, add authorizers-list labels (`es`/`en`/`pt`).
- **Bounded context**: Visits (creation, admin/concierge display), Unit Occupancies (authorizer resolution, already-existing `active_authorizers_for`), Notifications (unaffected — already unit-authorizer-scoped).
- **Non-goal**: no change to notification/authorization logic itself (`Notifications::CreateForVisit`, `DeliverPushNotificationJob`, `UnitOccupancy.active_authorizers_for`) — this change only removes the now-redundant host concept from data model and UI.
- **Dependencies**: none on other in-progress OpenSpec changes.
