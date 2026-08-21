## 1. Service object

- [x] 1.1 Add `app/services/mobile/organizations/detail.rb` implementing `.call(user:, organization_id:)`, returning `nil` when unauthorized/not found, or `{ name:, cover:, logo:, units: [...] }` otherwise.
- [x] 1.2 Look up the organization and check `user.member_of_tenant?(organization)` inside `ActsAsTenant.without_tenant`; return `nil` immediately if the organization doesn't exist or membership isn't active/invited.
- [x] 1.3 Once authorized, wrap unit/ownership/occupancy reads in `ActsAsTenant.with_tenant(organization)`, scoped to `user.person_for(organization)`.
- [x] 1.4 Compute the unit list as a union of active `UnitOwnership` and active `UnitOccupancy` unit ids (bounded queries, no N+1), building `is_owner` and `occupancy_type` per unit as outlined in design.md decision 3.
- [x] 1.5 Return each unit as `{ id:, code:, display_name:, unit_type:, is_owner:, occupancy_type: }`.
- [x] 1.6 Reshape the response to group units by `residential_property`: load units via `Unit.where(id: unit_ids).includes(:residential_property)`, `group_by(&:residential_property)`, and change the return value to `{ name:, cover:, logo:, residential_properties: [...] }` (drop the top-level `units:` key).
- [x] 1.7 Each `residential_properties` entry: `{ id:, name:, property_type:, address: { address_line:, city:, region: }, units: [...] }`, `units` built the same way as before (1.4/1.5) but scoped to that property's units only. Properties with no matching units must not appear (they simply won't be keys in the `group_by` result).

## 2. Route and controller

- [x] 2.1 Add route `GET /api/v1/mobile/organization/:id` under the existing `namespace :mobile` block in `config/routes.rb`.
- [x] 2.2 Add `app/controllers/api/v1/mobile/organizations_controller.rb#show`, calling `Mobile::Organizations::Detail.call(user: current_user, organization_id: params[:id])`.
- [x] 2.3 Render `404` (via the controller's existing `not_found`/`rescue_from ActiveRecord::RecordNotFound` pattern) when the service returns `nil`; otherwise render `200` with the payload under `data`.

## 3. Tests

- [x] 3.1 Unit test `Mobile::Organizations::Detail`: member with owned-only unit, occupied-only unit, unit held both ways (single entry, correct fields), inactive ownership/occupancy excluded, no units case, non-member returns `nil`, nonexistent organization id returns `nil`.
- [x] 3.2 Request test for `GET /api/v1/mobile/organization/:id`: happy path (200 with name/cover/logo/units), 404 for non-member, 404 for nonexistent id, 401 unauthenticated.
- [x] 3.3 Update 3.1/3.2 coverage for the new shape: units grouped under `residential_properties`, each with `id`/`name`/`property_type`/`address`; user with units across two different residential properties (two entries, correctly partitioned units); residential property with none of the user's units is omitted from the array.

## 4. Spec sync

- [x] 4.1 After implementation is verified, sync the new `mobile-organization-detail` spec into `openspec/specs/mobile-organization-detail/spec.md` (via `/opsx:sync` or archive flow).
