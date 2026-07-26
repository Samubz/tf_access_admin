## 1. Model and Migration

- [x] 1.1 Add migration removing `host_person_id` from `visits` (drop FK, index, column).
- [x] 1.2 Update `Visit` model: remove `belongs_to :host_person`, `host_active_on_unit` validation, `host_eligible?`/`active_ownership?`/`active_occupancy?` class methods, the `host_person`/`host_person_id` entries in `audited only: [...]`, `ransackable_associations`, `ransackable_attributes`, and `validates_same_tenant`.
- [x] 1.3 Delete `app/services/visits/eligible_hosts.rb` (and its test file, if any) — no longer used anywhere. (No test file existed for it.)

## 2. Admin Visit Creation (Backend)

- [x] 2.1 Update `Visits::Create` (`visit_params`/`build_visit`) to no longer read or require `host_person_id`.
- [x] 2.2 Remove `Admin::VisitsController#form_hosts` action and its route (`GET /admin/visits/form_hosts`).
- [x] 2.3 Remove `host_person_id` from `Admin::VisitsController#visit_params` and `#update_params`.

## 3. Resident Private API (Backend)

- [x] 3.1 Update `Residents::VisitContext::Result` to drop `host_person`; `#authorized?`/`#denial_reason` unaffected.
- [x] 3.2 Update `Residents::CreateAuthorizedVisit` to stop accepting/passing `host_person:`/`host_person_id:`.
- [x] 3.3 Update `Api::V1::Private::Units::VisitsController` to stop resolving/passing a host person.

## 4. Serializers — Replace Host with Unit Authorizers

- [x] 4.1 Add a shared helper computing `{ id, display_name }` for each `UnitOccupancy.active_authorizers_for(unit).person`, for reuse across serializers. (`VisitAuthorizersSerialization` concern in `app/serializers/concerns/`.)
- [x] 4.2 Update `Admin::VisitSerializer`: replace `host`/`host_person_id` with `authorizers`.
- [x] 4.3 Update `Admin::VisitDetailSerializer`: replace `host_detail` with `authorizers` (inherited from base).
- [x] 4.4 Update `Admin::VisitRestrictedSerializer`: replace `host_person_id`/host summary with `authorizers`.
- [x] 4.5 Update `Admin::VisitContextualDetailSerializer`: replace `host_detail` with `authorizers` (inherited from base).
- [x] 4.6 Update `Concierge::VisitSerializer` and `Concierge::VisitSummarySerializer`: replace `host_person_id`/host summary with `authorizers`.

## 5. Admin Frontend — Visit Creation Form

- [x] 5.1 Remove the host field/step from `VisitCreateGeneralStep.vue` (searchable select, labels, loading state).
- [x] 5.2 Update `visit_create.ts`: remove `host_person_id`/`host_display_name` from `VisitCreateForm`, `createEmptyVisitCreateForm`, and the Zod validation schema (`visitCreateGeneralSchema` or equivalent). Also removed unused `VisitHostOption` type.
- [x] 5.3 Update `useAdminVisitCreate.ts` to stop including `host_person_id` in the submit payload. (`useAdminVisitFormData.ts` had no host references.)
- [x] 5.4 Update `VisitAuthorizationSummary.vue` to drop the host row/prop.

## 6. Admin/Concierge Frontend — Display Authorizers Instead of Host

- [x] 6.1 Update `VisitDetailInfoTab.vue` and `VisitDetailContextualPanel.vue` to render the `authorizers` list instead of a single host.
- [x] 6.2 Update `useAdminVisitsList.ts` and `admin/visits/index.vue` (list/table) to drop the host column and show authorizers instead. Also fixed a ransack search predicate (`..._or_host_person_display_name_or_...`) that referenced the now-removed association and would have raised at runtime.
- [x] 6.3 Update concierge visit list/detail Vue components (`VisitOperationalSummary.vue`, `concierge/visits/index.vue`) to drop host display and show authorizers. Also found (via `npm run check` after the type changes) two more Vue files the initial grep missed because they use `.host` without the literal string "host_": `UnitVisitsTable.vue` and `VisitDetailRestrictedPanel.vue` — both updated to show authorizers.
- [x] 6.4 Update TypeScript types in `types/visit.ts`: added `VisitAuthorizerSummary`, replaced `host`/`host_detail`/`host_person_id` with `authorizers: VisitAuthorizerSummary[]` across `ConciergeVisitListItem`, `AdminVisitListItem`, `AdminVisitDetail`, `AdminVisitRestrictedSerializer`, `AdminVisitContextualDetail`.

## 7. i18n

- [x] 7.1 Remove host-related i18n keys (`es`/`en`/`pt`) under `admin.visits.new.general.fields.host`, `.placeholders.host`, `.empty.hosts`, `.loading.hosts`, `.validations.host_required`, `admin.visits.show.sections.host`, and the now-unused `activerecord.errors.models.visit.attributes.host_person` message. Also removed prose mentions of "host"/"anfitrión"/"anfitrião" in descriptions and search placeholders (initial grep for the literal string "host" missed the es/pt translations, which don't contain that substring — required a second pass grepping "anfitri").
- [x] 7.2 Add i18n keys (`es`/`en`/`pt`) for the "Autorizadores"/"Authorizers"/"Autorizadores" label wherever host was previously labeled (detail panels, list/table columns, summary panel).

## 8. Tests

- [x] 8.1 Update/remove `host_person`/`host_person_id` references across all 24 affected test files (confirmed via `grep -rl "host_person" test/`), not just the visit-feature-specific ones. Many are tests for *unrelated* features (unit/property lifecycle, section destroy protection) that only incidentally create a `Visit` as setup data and will raise `ActiveRecord::UnknownAttributeError` once the column is dropped if left unchanged:
  - Visit-feature tests: `test/models/visit_test.rb`, `test/models/visit/initial_status_test.rb`, `test/models/visit/state_machine_test.rb`, `test/models/visit_operational_scopes_test.rb`, `test/models/visit_status_history_test.rb`, `test/integration/visit_lifecycle_test.rb`, `test/policies/visit_policy_test.rb`, `test/serializers/visit_serializer_test.rb`, `test/serializers/concierge_visit_serializer_test.rb`, `test/services/visits/*` (concierge_check_in_out, concierge_search, functional_history, resend_notification, services), `test/services/notifications/create_for_visit_test.rb`, `test/jobs/deliver_push_notification_job_test.rb`, `test/controllers/admin/visits_controller_test.rb`, `test/controllers/admin/visits/check_ins_controller_test.rb`, `test/controllers/concierge/visits_controller_test.rb`, `test/controllers/api/v1/private/units/visits_controller_test.rb`.
  - Incidental setup-data only (unrelated feature under test): `test/controllers/admin/residential_properties/units_controller_test.rb`, `test/models/property_section_destroy_protection_test.rb`, `test/services/properties/archive_test.rb`, `test/services/units/foundation_coverage_test.rb`, `test/services/units/lifecycle_test.rb`.
  - Also fixed two leftover production `.includes(:host_person)` calls found via the resulting `ActiveRecord::AssociationNotFoundError` in `concierge/visits_controller.rb` (`set_visit`) and `admin/residential_properties/units_controller.rb` (units show visits list) — these were missed in Section 2/6 grep passes. Also removed the now-dangling `Person#visits_as_host` association (`foreign_key: :host_person_id`) in `app/models/person.rb`, confirmed unused elsewhere.
  - `test/serializers/visit_serializer_test.rb` required a real rewrite (not just deletion): added a `UnitOccupancy` with `can_authorize_visits: true` for the owner in setup (previously only `UnitOwnership` existed, which is not sufficient for the `authorizers` list), and rewrote the `data[:host]`/`data[:host_detail]` assertions to check `data[:authorizers]`.
  - Removed the obsolete `admin/visits_controller_test.rb` test "form_hosts matches accent-insensitively..." since the `form_hosts` action/route was deleted in Section 2.
  - Full suite run: 1067 runs, 3348 assertions, 0 failures, 0 errors, 0 skips.
- [x] 8.2 Add/update serializer tests confirming `authorizers` reflects `UnitOccupancy.active_authorizers_for(unit)`. Added a test in `visit_serializer_test.rb` asserting an empty `authorizers` array when the unit has no active authorizer; the "includes" case is covered by the rewritten host->authorizers assertion. The underlying `active_authorizers_for` scope (empty/multiple/excludes-non-authorizing) is already thoroughly covered in `test/models/unit_occupancy_test.rb`.
- [x] 8.3 Added `"create succeeds without any host-related param"` in `test/services/visits/services_test.rb` asserting `@visit_params` has no `host_person_id` key and `Visits::Create.call` still persists. `Residents::CreateAuthorizedVisit` (no host param) is exercised via the concierge controller test "a visit created via the resident flow appears in the concierge list".
- [x] 8.4 Ran `npm run check` — only the 2 pre-existing unrelated errors remain (`MultiFileGridUpload.vue` missing `@/types/product`, `useUnitAddOwnerDrawer.ts` type mismatch), both present before this change.

## 9. Verification

- [x] 9.1 Not run manually in-browser this session; covered by `admin/visits_controller_test.rb` (create/edit/show flows) and `visit_serializer_test.rb`/detail Vue components confirming `authorizers` renders. No host step exists anywhere in the form (`VisitCreateGeneralStep.vue` rewritten in Section 5).
- [x] 9.2 Confirmed via `test/controllers/api/v1/private/units/visits_controller_test.rb` — full suite (19 runs) passes, including the rewritten 6.9 actor/person-reference test with no `host_person_id` assertion.
- [x] 9.3 Ran targeted + full suite: all Visit/authorizer-related test files pass individually and the full `bin/rails test` run is green (1067/1067, 0 failures/errors).
