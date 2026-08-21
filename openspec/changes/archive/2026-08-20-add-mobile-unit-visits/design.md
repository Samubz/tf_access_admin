## Context

Mobile clients already have `GET /api/v1/mobile/organization/:id` (branding + residential properties + units) and `GET /api/v1/mobile/organization/:organization_id/residential_property/:id` (a single property's identity/address + the user's units within it). Neither returns anything about `Visit` records. This change adds the next drill-down: given a residential property and one of its units, return the visits scheduled for that unit on a given day — for a resident's "today's visits" screen.

`Visit` `acts_as_tenant :organization` and has `belongs_to :visitor_person, class_name: "Person"` — `Person#display_name` (not `#name`) is the field to surface as `visitor_name`. `Visit#checked_in_at` / `#checked_out_at` are nullable timestamps set only once the visit actually happens; a `pending` or `authorized` visit will have both `null`. `Visit#scheduled_at` is the field to filter on for "which day", backed by an existing `(organization_id, unit_id, scheduled_at)` index — filtering here does not require a new index.

`ResidentialProperty#timezone` (default `"America/Santiago"`) already exists and is the correct basis for "today" — the property's local day, not the server's or the requesting device's.

Unlike the private resident API (`POST /api/v1/private/units/:unit_id/visits`, gated by `Residents::VisitContext` + `Authorization::Resolver` capabilities `create_visits`/`authorize_visits`), this is a read-only listing gated by a much simpler, explicit product decision: only an active `UnitOccupancy` on the specific unit grants access — an active `UnitOwnership` alone does not. `Residents::VisitContext` is deliberately not reused here; it answers a different question ("can this user authorize a new visit on this unit") than this endpoint needs ("is this user a current resident of this unit").

This route also differs structurally from the two prior mobile endpoints: it carries no `:organization_id` path segment at all. `:id` (residential property) and `:unit_id` are the only path params, so the organization must be discovered from the property before any tenant-scoped query can run.

## Goals / Non-Goals

**Goals:**
- `GET /api/v1/mobile/residential_property/:id/unit/:unit_id/visitas` returns an array (never a wrapping object) of visits scheduled for that unit on the requested day.
- Optional `day` query param (`YYYY-MM-DD`); default is "today" in `ResidentialProperty#timezone`. Malformed `day` → `422 Unprocessable Entity`.
- Authorization: the authenticated user's `Person` must have an active `UnitOccupancy` on the requested unit. Active `UnitOwnership` alone is insufficient.
- The residential property must be `status == PropertyStatuses::ACTIVE`; the unit must have `status` in `[UnitStatuses::AVAILABLE, UnitStatuses::OCCUPIED]`.
- Every authorization/existence failure (organization/property/unit not found or not eligible, no active occupancy) responds identically `404 Not Found` — same unified non-disclosure posture as the two prior mobile endpoints.
- A day with zero scheduled visits, once authorization passes, responds `200 OK` with `[]` — not `404`. This is the one place this endpoint's empty-result rule diverges from `add-mobile-residential-property-detail`'s "empty result is 404" rule, because "no visits today" is an ordinary, frequent, legitimate state rather than a signal of a stale/invalid link.
- Each entry: `{ visitor_name, checked_in_at, checked_out_at, status }`. `status` is the raw `Visit#status` value (no I18n label), matching the raw-value convention already used for `occupancy_type` in the two prior endpoints. All `VisitStatuses::ALL` values are included — no status filtering.

**Non-Goals:**
- No pagination.
- No visit creation, authorization, check-in, or check-out — read-only.
- No `authorized_by`/authorizer data, no unit/property echo in the response body.
- No reuse of `Residents::VisitContext` / `Authorization::Resolver` capabilities — the occupancy-only check is the entire gate.
- No handling of `UnitOccupancy#starts_at`/`#ends_at` validity-window bounds beyond `status == ACTIVE` — consistent with how the two prior mobile endpoints already treat active ownership/occupancy (status-only, no date-range check); revisit only if that assumption is revisited platform-wide.

## Decisions

**1. New service `Mobile::ResidentialProperties::Units::Visits::Index.call(user:, residential_property_id:, unit_id:, day: nil)`**
Returns `nil` for any authorization/existence failure (controller renders `404`), or an array (possibly empty) of visit hashes otherwise — the array-vs-`nil` distinction is what lets the controller tell "authorized but empty" apart from "not authorized," unlike the two prior services which only ever returned `nil` or a populated hash.

**2. Tenant bootstrap from the property, not from a path `:organization_id`**
```ruby
organization = ActsAsTenant.without_tenant { ResidentialProperty.find_by(id: residential_property_id)&.organization }
return nil if organization.blank?

ActsAsTenant.with_tenant(organization) do
  property = ResidentialProperty.find_by(id: residential_property_id)
  return nil if property.blank? || property.status != PropertyStatuses::ACTIVE
  # ... unit, occupancy, visits — all re-resolved here, inside the tenant
end
```
The first lookup is untrusted and used only to learn which organization to open; it is never used to authorize anything by itself. Every subsequent read — the property again, the unit, the occupancy, the visits — happens inside `ActsAsTenant.with_tenant(organization)`, so a `residential_property_id` cannot be used to infer or leak data from a different organization; the second, trusted lookup is what actually gates the response.
- *Alternative considered*: keep an explicit `:organization_id` path param like the two prior endpoints, for a consistent URL shape across all three. Rejected — the requested route (`residential_property/:id/unit/:unit_id/visitas`) already fully disambiguates the tenant transitively through the property, and mobile clients reach this screen by navigating from an already-resolved property/unit, never by constructing the URL from an organization id they'd otherwise have to carry forward unused.

**3. Unit + occupancy resolution, scoped and combined into one gate**
```ruby
unit = Unit.find_by(id: unit_id, residential_property_id: property.id)
return nil if unit.blank? || !ELIGIBLE_UNIT_STATUSES.include?(unit.status)

person = user.person_for(organization)
return nil if person.blank?

occupancy = person.unit_occupancies.find_by(unit_id: unit.id, status: OccupancyStatuses::ACTIVE)
return nil if occupancy.blank?
```
`ELIGIBLE_UNIT_STATUSES = [UnitStatuses::AVAILABLE, UnitStatuses::OCCUPIED]`, same constant/definition already introduced in `Mobile::Organizations::ResidentialProperties::Detail`. No `owned_unit_ids`/union computation here (unlike the two prior services) — this endpoint checks exactly one unit for exactly one person, a single `find_by`, not a bounded multi-unit query.
- *Alternative considered*: reuse the ownership ∪ occupancy union pattern from the two prior services for consistency. Rejected per explicit product decision — ownership alone must not grant access here.

**4. Day resolution in the property's timezone, converted to a UTC range for the query**
```ruby
zone = ActiveSupport::TimeZone[property.timezone]
date =
  if day_param.present?
    Date.iso8601(day_param) rescue (return :invalid_day)
  else
    zone.today
  end
range = zone.local(date.year, date.month, date.day).beginning_of_day.utc..zone.local(date.year, date.month, date.day).end_of_day.utc

visits = Visit.where(unit_id: unit.id, scheduled_at: range).order(:scheduled_at)
```
`Date.iso8601` raises `ArgumentError` on a malformed string; the service surfaces this as a distinguishable outcome (e.g. a raised error or a sentinel) so the controller can render `422` instead of the unified `404` — this is the one failure mode in this endpoint that is a client input error, not an authorization/existence gate, so it does not fold into the unified `404`.
- *Alternative considered*: default to `Date.current` (server/UTC "today") instead of the property's local day. Rejected — a property in `America/Santiago` past midnight UTC but still "yesterday" locally (or vice versa) would silently show the wrong day; this is exactly the class of bug the explicit product decision was meant to avoid.

**5. Response shape per visit**
```ruby
{
  visitor_name: visit.visitor_person.display_name,
  checked_in_at: visit.checked_in_at,
  checked_out_at: visit.checked_out_at,
  status: visit.status
}
```
`Person#display_name` is the correct field — `Person` has no `#name` method/column (confirmed against `app/models/person.rb`); `#first_name`/`#last_name` exist but `display_name` is the already-maintained presentational field used elsewhere (e.g. `Unit#display_name`, `Admin::VisitSerializer#visitor`).

**6. Controller and route mirror the existing mobile pattern, nested by URL segment rather than by namespace depth**
`app/controllers/api/v1/mobile/residential_properties/units/visits_controller.rb` (`Api::V1::Mobile::ResidentialProperties::Units::VisitsController#index`), thin controller calling the service and rendering `data:` array on success. Distinguishing `nil` (→ `404`) from `:invalid_day` (→ `422`) from an array (→ `200`) is the only branching the controller needs. Route: `get "residential_property/:id/unit/:unit_id/visitas", to: "residential_properties/units/visits#index"` inside the existing `namespace :mobile` block.

## Risks / Trade-offs

- [Risk] `:id` or `:unit_id` could be a non-UUID or belong to an unrelated/different-organization resource → both lookups (`ResidentialProperty.find_by`, `Unit.find_by(..., residential_property_id: property.id)`) return `nil` safely, falling through to the unified `404`. No special-casing needed.
- [Trade-off] Occupancy-only authorization (decision 3) means an owner who does not also hold an active occupancy on their own unit cannot see its visit log through this endpoint — accepted as the confirmed product decision; owners have the admin-web `Admin::VisitsController` surface for that.
- [Trade-off] Skipping `UnitOccupancy#starts_at`/`#ends_at` bounds (Non-Goals) means an occupancy record marked `status: active` but administratively backdated/future-dated still grants access — same latent gap already accepted in the two prior mobile services, not introduced here.
- [Risk] Timezone conversion bugs (decision 4) are the highest-complexity part of this endpoint — worth explicit test coverage for a day boundary near local midnight (e.g. a visit at 23:30 America/Santiago should appear under that local day, not the UTC day it falls into after conversion).

## Migration Plan

No data migration. Single deploy: new route, controller, service, tests. Rollback is a plain revert.
