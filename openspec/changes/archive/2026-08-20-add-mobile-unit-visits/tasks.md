## 1. Service object

- [x] 1.1 Add `app/services/mobile/residential_properties/units/visits/index.rb` implementing `Mobile::ResidentialProperties::Units::Visits::Index.call(user:, residential_property_id:, unit_id:, day: nil)`, returning `nil` for any authorization/existence failure, `:invalid_day` for a malformed `day` param, or an array (possibly empty) of visit hashes otherwise.
- [x] 1.2 Bootstrap the organization from an untrusted lookup: `ActsAsTenant.without_tenant { ResidentialProperty.find_by(id: residential_property_id)&.organization }`; return `nil` if blank.
- [x] 1.3 Inside `ActsAsTenant.with_tenant(organization)`, re-resolve `property = ResidentialProperty.find_by(id: residential_property_id)`; return `nil` if it doesn't exist or `status != PropertyStatuses::ACTIVE`.
- [x] 1.4 Resolve `unit = Unit.find_by(id: unit_id, residential_property_id: property.id)`; return `nil` if it doesn't exist or `status` not in `[UnitStatuses::AVAILABLE, UnitStatuses::OCCUPIED]`.
- [x] 1.5 Resolve `person = user.person_for(organization)`, then `occupancy = person&.unit_occupancies&.find_by(unit_id: unit.id, status: OccupancyStatuses::ACTIVE)`; return `nil` if `person` or `occupancy` is blank. Do NOT check `UnitOwnership` — occupancy is the sole gate (design.md decision 3).
- [x] 1.6 Parse `day`: if present, `Date.iso8601(day)` and return `:invalid_day` (not `nil`) if it raises `ArgumentError`/`TypeError`; if absent, default to "today" in `ActiveSupport::TimeZone[property.timezone]`.
- [x] 1.7 Compute the day's start/end as a UTC range in `property.timezone` (design.md decision 4) and query `Visit.where(unit_id: unit.id, scheduled_at: range).order(:scheduled_at)` — no status filter (all `VisitStatuses::ALL` included).
- [x] 1.8 Map each visit to `{ visitor_name: visit.visitor_person.display_name, checked_in_at:, checked_out_at:, status: }`.

## 2. Route and controller

- [x] 2.1 Add route `get "residential_property/:id/unit/:unit_id/visitas", to: "residential_properties/units/visits#index"` inside the existing `namespace :mobile` block in `config/routes.rb`.
- [x] 2.2 Add `app/controllers/api/v1/mobile/residential_properties/units/visits_controller.rb#index` (`Api::V1::Mobile::ResidentialProperties::Units::VisitsController`), calling `Mobile::ResidentialProperties::Units::Visits::Index.call(user: current_user, residential_property_id: params[:id], unit_id: params[:unit_id], day: params[:day])`.
- [x] 2.3 Branch on the service result: `nil` → `raise ActiveRecord::RecordNotFound` (404 via `Api::V1::Mobile::BaseController`'s existing `rescue_from`); `:invalid_day` → render `422` with an error body; otherwise render `200` with `{ data: result }`.

## 3. Tests

- [x] 3.1 Unit test `Mobile::ResidentialProperties::Units::Visits::Index`: resident with a visit scheduled today (default day), resident with a visit on an explicit `day`, day-boundary case where a visit's `scheduled_at` falls on different calendar days in the property's timezone vs. UTC, malformed `day` returns `:invalid_day`, all seven `VisitStatuses::ALL` values included with no filtering, zero visits on a valid day returns `[]` (not `nil`), owner-without-occupancy returns `nil`, inactive-occupancy returns `nil`, nonexistent residential property id returns `nil`, nonexistent/cross-property unit id returns `nil`, non-active property status returns `nil`, ineligible unit status returns `nil`.
- [x] 3.2 Request test for `GET /api/v1/mobile/residential_property/:id/unit/:unit_id/visitas`: happy path (200 with array of `visitor_name`/`checked_in_at`/`checked_out_at`/`status`), 200 with empty array when no visits that day, 422 for malformed `day`, 404 for owner-without-occupancy, 404 for nonexistent property/unit ids, 404 for non-active property, 404 for ineligible unit status, 401 unauthenticated.

## 4. Spec sync

- [x] 4.1 After implementation is verified, sync the new `mobile-unit-visits` spec into `openspec/specs/mobile-unit-visits/spec.md` (via `/opsx:sync` or archive flow).
