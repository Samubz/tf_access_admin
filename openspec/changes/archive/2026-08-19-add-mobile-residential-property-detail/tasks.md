## 1. Service object

- [x] 1.1 Add `app/services/mobile/organizations/residential_properties/detail.rb` implementing `Mobile::Organizations::ResidentialProperties::Detail.call(user:, organization_id:, residential_property_id:)`, returning `nil` when unauthorized/not-found/no-eligible-units, or `{ id:, name:, property_type:, address:, units: [...] }` otherwise.
- [x] 1.2 Look up the organization and check `user.member_of_tenant?(organization)` inside `ActsAsTenant.without_tenant`; return `nil` immediately if the organization doesn't exist or membership isn't active/invited (mirrors `Mobile::Organizations::Detail`).
- [x] 1.3 Once authorized, open `ActsAsTenant.with_tenant(organization)` and look up `ResidentialProperty.find_by(id: residential_property_id)`; return `nil` if it doesn't exist or `status != PropertyStatuses::ACTIVE`. Do not add a separate `organization_id` equality check — rely on `acts_as_tenant` scoping the lookup.
- [x] 1.4 Compute `owned_unit_ids` and `occupancy_type_by_unit_id` for `user.person_for(organization)` via the same 2 bounded queries as `Mobile::Organizations::Detail` (active `UnitOwnership` / active `UnitOccupancy`).
- [x] 1.5 Query `Unit.where(id: unit_ids, residential_property_id: property.id, status: [UnitStatuses::AVAILABLE, UnitStatuses::OCCUPIED])`. Return `nil` if this collection is empty.
- [x] 1.6 Build `address` as `{ address_line:, city:, region: }` from the property, and each unit as `{ id:, code:, display_name:, unit_type:, is_owner:, occupancy_type: }` as outlined in design.md decision 3.
- [x] 1.7 Return `{ id: property.id, name: property.name, property_type: property.property_type, address:, units: }`.

## 2. Route and controller

- [x] 2.1 Add nested route `get "organization/:organization_id/residential_property/:id", to: "organizations/residential_properties#show"` inside the existing `namespace :mobile` block in `config/routes.rb`.
- [x] 2.2 Add `app/controllers/api/v1/mobile/organizations/residential_properties_controller.rb#show` (namespaced `Api::V1::Mobile::Organizations::ResidentialPropertiesController`), calling `Mobile::Organizations::ResidentialProperties::Detail.call(user: current_user, organization_id: params[:organization_id], residential_property_id: params[:id])`.
- [x] 2.3 Render `404` (reusing `Api::V1::Mobile::BaseController`'s existing `rescue_from ActiveRecord::RecordNotFound` pattern, same as `organizations_controller.rb`) when the service returns `nil`; otherwise render `200` with the payload under `data`.

## 3. Tests

- [x] 3.1 Unit test `Mobile::Organizations::ResidentialProperties::Detail`: member with owned-only unit, occupied-only unit, unit held both ways (single entry, correct fields), inactive ownership/occupancy excluded, unit with ineligible status (`inactive`/`maintenance`/`archived`) excluded despite active ownership/occupancy, unit belonging to a different residential property excluded, non-member returns `nil`, nonexistent organization id returns `nil`, nonexistent/cross-organization residential property id returns `nil`, non-active property status (`draft`/`created`/`configured`/`inactive`/`archived`) returns `nil`, member with zero eligible units in an active property returns `nil`.
- [x] 3.2 Request test for `GET /api/v1/mobile/organization/:organization_id/residential_property/:id`: happy path (200 with id/name/property_type/address/units), 404 for non-member, 404 for nonexistent organization id, 404 for nonexistent residential property id, 404 for non-active property, 404 for member with zero eligible units, 401 unauthenticated.

## 4. Spec sync

- [x] 4.1 After implementation is verified, sync the new `mobile-residential-property-detail` spec into `openspec/specs/mobile-residential-property-detail/spec.md` (via `/opsx:sync` or archive flow).
