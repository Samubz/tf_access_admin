## Context

`GET /api/v1/mobile/organization/:id` ([app/controllers/api/v1/mobile/organizations_controller.rb](../../../app/controllers/api/v1/mobile/organizations_controller.rb), service `Mobile::Organizations::Detail`) already returns an organization's branding plus its residential properties grouped with the user's units in each. This change adds the drill-down: given an organization id and a residential property id, return just that property's identity/address plus the user's units within it — for a property-detail screen reached from the organization-detail list.

As with the existing endpoint, mobile sessions never set `ActsAsTenant.current_tenant` — `Api::V1::Mobile::BaseController` has no tenant-resolution `before_action`. Unlike the existing endpoint, the route here carries two untrusted path params: `:organization_id` and `:id` (the residential property). `:organization_id` is validated against the user's own memberships exactly like today; `:id` cannot be trusted to belong to that organization until it's read *inside* the resolved tenant, because `ResidentialProperty` `acts_as_tenant :organization` — a tenant-scoped `find_by(id:)` for a property belonging to a different organization simply returns `nil`, which is the desired "not found" outcome without any extra cross-tenant check.

`Unit`, `UnitOwnership`, `UnitOccupancy`, and `ResidentialProperty` all `acts_as_tenant :organization`. `ResidentialProperty` is also `acts_as_paranoid` (soft-deleted properties are excluded from lookups by default). `UnitOccupancy` has a unique index `(organization_id, unit_id, person_id) WHERE deleted_at IS NULL`, so a person has at most one occupancy row (active or not) per unit — no risk of multiple `occupancy_type` values for the same unit/person pair (same invariant the archived `add-mobile-organization-detail` design relied on).

## Goals / Non-Goals

**Goals:**
- `GET /api/v1/mobile/organization/:organization_id/residential_property/:id` returns `data.id`, `data.name`, `data.property_type`, `data.address` (`address_line`, `city`, `region`), and `data.units`.
- `data.units` is one entry per unit within that property with an active `UnitOwnership` and/or active `UnitOccupancy` for the user's `Person`, unioned (no duplicate for a unit held both ways), further restricted to `Unit#status` in `[UnitStatuses::AVAILABLE, UnitStatuses::OCCUPIED]`.
- Each unit: `{ id, code, display_name, unit_type, is_owner, occupancy_type }`, same shape as the existing endpoint.
- The residential property itself must have `status == PropertyStatuses::ACTIVE` for the endpoint to return anything.
- Single unified `404` for every failure mode (see Decisions) — no `200` with an empty `units` array, unlike `organization/:id`.

**Non-Goals:**
- No pagination on `units`.
- No property section detail, no `country`/`timezone`/other `ResidentialProperty` fields beyond `name`, `property_type`, and the three address fields.
- No role/permission data beyond `is_owner`/`occupancy_type`.
- No write operations; read-only endpoint.
- No reuse of `OrganizationPolicy`/`Authorization::Resolver` — same rationale as the archived change: both assume an admin/tenant-admin context that doesn't exist for mobile sessions.
- No distinguishing response body/status between "not a member", "property not active", and "no eligible units" — all collapse to the same `404`.

## Decisions

**1. New service `Mobile::Organizations::ResidentialProperties::Detail.call(user:, organization_id:, residential_property_id:)`**
Returns `nil` for any unauthorized/not-found/empty-result case (controller renders `404`), or a hash `{ id:, name:, property_type:, address:, units: [...] }` otherwise. Mirrors `Mobile::Organizations::Detail`'s class-method entry point.

**2. Two-stage tenant resolution: organization first (untrusted membership gate), property second (trusted tenant-scoped read)**
```ruby
organization = ActsAsTenant.without_tenant { Organization.find_by(id: organization_id) }
return nil if organization.blank?
return nil unless user.member_of_tenant?(organization)

ActsAsTenant.with_tenant(organization) do
  property = ResidentialProperty.find_by(id: residential_property_id)
  return nil if property.blank? || property.status != PropertyStatuses::ACTIVE

  person = user.person_for(organization)
  # unit/ownership/occupancy queries scoped to this tenant + this property only
end
```
The property lookup happens only after membership is established and only inside `with_tenant(organization)`, so a property id belonging to a different organization (or a nonexistent id) resolves to `nil` the same way a missing organization does — no separate `property.organization_id == organization.id` check is needed; `acts_as_tenant` enforces it structurally.
- *Alternative considered*: validate `property.organization_id == organization.id` explicitly before/instead of relying on tenant scoping. Rejected — redundant given `acts_as_tenant`, and duplicating the check invites the two to drift.

**3. Unit union computed with 2 bounded queries scoped to the property, same pattern as the archived change, plus a status filter**
```ruby
owned_unit_ids = person.unit_ownerships.where(status: UnitOwnership::STATUS_ACTIVE).distinct.pluck(:unit_id).to_set
occupancy_type_by_unit_id = person.unit_occupancies.where(status: OccupancyStatuses::ACTIVE).pluck(:unit_id, :occupancy_type).to_h
unit_ids = owned_unit_ids | occupancy_type_by_unit_id.keys

units = Unit.where(id: unit_ids, residential_property_id: property.id, status: [ UnitStatuses::AVAILABLE, UnitStatuses::OCCUPIED ])
return nil if units.empty?
```
where the eligible-status filter is `[UnitStatuses::AVAILABLE, UnitStatuses::OCCUPIED]` (a unit in `inactive`, `maintenance`, or `archived` never appears here, even with active ownership/occupancy). Then per unit: `is_owner: owned_unit_ids.include?(unit.id)`, `occupancy_type: occupancy_type_by_unit_id[unit.id]`. If the filtered `units` collection is empty, the service returns `nil` (unified `404`), matching decision 4.
- *Alternative considered*: reuse `Mobile::Organizations::Detail`'s `units_for` by extracting a shared helper. Deferred — the property-scoped version adds a `residential_property_id` + status filter and a different empty-result outcome (`nil` vs. `[]`), so sharing now would need a parameter to toggle both; revisit if a third caller appears.

**4. Every failure mode returns the same `nil` → controller `404`, no distinguishing signal**
No-membership, organization not found, property not found, property not `active`, and zero eligible units after the unit-status filter all short-circuit to `nil`. The controller's existing `raise ActiveRecord::RecordNotFound if result.blank?` pattern (already used by `organizations_controller.rb`) needs no changes to express this — a blank/`nil` result is already `404` regardless of cause.
- *Alternative considered*: `200` with `units: []` when the user is a member and the property is active but has no eligible units, mirroring `organization/:id`'s "member with no units" scenario. Rejected per explicit product decision — this endpoint's `:id` is only ever reached by navigating from a unit/property the user is already known to have, so an empty result here signals a stale/invalid link rather than a legitimate empty state, and collapsing it into the same `404` as "not authorized" keeps the response surface simpler to reason about.

**5. Controller and route mirror `organizations_controller.rb`, nested under the same `namespace :mobile` block**
`app/controllers/api/v1/mobile/organizations/residential_properties_controller.rb` (namespaced under `Api::V1::Mobile::Organizations`, matching the admin-side `ResidentialProperties::UnitsController` nesting convention), single `#show` action calling the new service and rendering `data` on success or `404` via the same `not_found`/`rescue_from ActiveRecord::RecordNotFound` pattern already defined on `Api::V1::Mobile::BaseController`. Route added as `get "organization/:organization_id/residential_property/:id", to: "organizations/residential_properties#show"` inside the existing `namespace :mobile` block in `config/routes.rb`.

## Risks / Trade-offs

- [Risk] `:organization_id` or `:id` could be a non-UUID or a UUID for an unrelated resource type → both `find_by(id:)` calls return `nil` safely (no exception), falling through to the same `404` path. No special-casing needed.
- [Risk] A unit with an active ownership AND active occupancy for the same person must appear exactly once → covered by decision 3 (`unit_ids` built from a union of two id sets, single `Unit.where(...)` read).
- [Trade-off] Collapsing "not a member", "property inactive", and "no eligible units" into one `404` (decision 4) means a legitimate member with a temporarily inactive property gets the same response as someone probing an id they have no access to — accepted as the confirmed non-disclosure posture; mobile clients always reach `:id` via a prior authorized list, never free-typed.
- [Trade-off] The unit-status eligibility filter (`available`/`occupied` only) is stricter than `organization/:id`, which applies no `Unit#status` filter at all. This is an intentional, explicit product decision for this endpoint only — worth re-confirming if the two endpoints are ever expected to show consistent unit counts for the same user/property.

## Migration Plan

No data migration. Single deploy: new route, controller, service, tests. Rollback is a plain revert.
