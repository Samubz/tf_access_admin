## Context

`GET /api/v1/mobile/me` ([app/controllers/api/v1/mobile/me_controller.rb](../../../app/controllers/api/v1/mobile/me_controller.rb)) already lists the organizations a mobile client user belongs to (id, name, logo, units_count) via `Mobile::Me::OrganizationsSummary`. This change adds the drill-down: given one organization id, return its branding (name, cover, logo) plus the residential properties the user has units in, each with address/name/type and the specific units the user is linked to within that property, with per-unit ownership/occupancy detail.

As with `/me`, mobile sessions never set `ActsAsTenant.current_tenant` — `Api::V1::Mobile::BaseController` has no tenant-resolution `before_action`, and `Api::V1::Mobile::Auth::SessionsController#create` authenticates without requiring or resolving an organization. So `:id` in the route is the only signal for which tenant to read, and it comes from an untrusted path param — it must be validated against the user's own memberships before any tenant-scoped query runs.

`Unit`, `UnitOwnership`, and `UnitOccupancy` all `acts_as_tenant :organization`. `UnitOccupancy` has a unique index `(organization_id, unit_id, person_id) WHERE deleted_at IS NULL`, so a person has at most one occupancy row (active or not) per unit — no risk of multiple `occupancy_type` values for the same unit/person pair.

## Goals / Non-Goals

**Goals:**
- `GET /api/v1/mobile/organization/:id` returns `data.name`, `data.cover`, `data.logo`, `data.residential_properties`.
- `data.residential_properties` is one entry per `ResidentialProperty` in the organization where the user has at least one linked unit. Properties with none of the user's units are omitted (not returned with an empty `units` array).
- Each residential property: `{ id, name, property_type, address: { address_line, city, region }, units: [...] }`.
- `units` within each property is one entry per unit with an active `UnitOwnership` and/or active `UnitOccupancy` for the user's `Person` in that organization — union, no duplicate entries for a unit held both ways.
- Each unit: `{ id, code, display_name, unit_type, is_owner, occupancy_type }`, `occupancy_type` raw from `OccupancyTypes::ALL` or `null`.
- Authorization gate: no active/invited membership in the target organization → `404`, not `403` (non-disclosure of org existence, consistent with tenant isolation elsewhere).

**Non-Goals:**
- No pagination on `residential_properties` or `units`.
- No property section detail, no `country`/`timezone`/other `ResidentialProperty` fields beyond `name`, `property_type`, and the three address fields.
- No role/permission data beyond `is_owner`/`occupancy_type`.
- No write operations; read-only endpoint.
- No reuse of `OrganizationPolicy`/`Authorization::Resolver` — both assume an admin/tenant-admin context (`same_organization?`, `Current.organization`) that doesn't exist for mobile sessions.

## Decisions

**1. New service `Mobile::Organizations::Detail.call(user:, organization_id:)`**
Returns `nil` when the user has no active/invited membership in `organization_id` (controller renders 404), or a hash `{ name:, cover:, logo:, units: [...] }` otherwise. Mirrors the `Mobile::Me::OrganizationsSummary` shape (class method entry point, small and testable in isolation).
- *Alternative considered*: a Pundit policy (`Mobile::OrganizationPolicy`) instead of a plain membership check inside the service. Rejected — Pundit's `NotAuthorizedError` maps to `403` in `Api::V1::Mobile::BaseController#forbidden`, but the desired response here is `404` (non-disclosure), which is simpler to express as "record not found" than as a policy exception mapped to a different status.

**2. Membership validation happens outside any tenant, unit/ownership/occupancy reads happen inside `ActsAsTenant.with_tenant(organization)`**
```ruby
organization = ActsAsTenant.without_tenant { Organization.find_by(id: organization_id) }
return nil if organization.blank?
return nil unless user.member_of_tenant?(organization)  # existing User method

ActsAsTenant.with_tenant(organization) do
  person = user.person_for(organization)
  # unit/ownership/occupancy queries scoped to this tenant only
end
```
Reuses `User#member_of_tenant?` (already the exact active/invited membership check) instead of re-deriving it — same rule as `add-mobile-me-organizations`.
- *Alternative considered*: resolve tenant first via `ActsAsTenant.with_tenant` then check membership inside. Rejected — would run tenant-scoped queries (even just the organization lookup) before authorization is established, which is backwards for a security-sensitive gate; validating membership in a tenant-less context first, then opening the tenant window only for the authorized read, keeps the blast radius of a mistake smaller.

**3. Unit union computed with 2 bounded queries, not per-unit N+1; grouped by `residential_property` in memory**
```ruby
owned_unit_ids = person.unit_ownerships.where(status: UnitOwnership::STATUS_ACTIVE).distinct.pluck(:unit_id)
occupancy_rows = person.unit_occupancies.where(status: OccupancyStatuses::ACTIVE).pluck(:unit_id, :occupancy_type)
occupancy_type_by_unit_id = occupancy_rows.to_h
unit_ids = (owned_unit_ids | occupancy_type_by_unit_id.keys)
units = Unit.where(id: unit_ids).includes(:residential_property)
units_by_property = units.group_by(&:residential_property)
```
Then per unit: `is_owner: owned_unit_ids.include?(unit.id)`, `occupancy_type: occupancy_type_by_unit_id[unit.id]`. Same bounded-query approach as `Mobile::Me::OrganizationsSummary`, extended with `includes(:residential_property)` (1 extra bounded query) to avoid N+1 when grouping — a residential property with none of the user's units never appears in `units_by_property`, so no separate "which properties have zero units" filtering step is needed.

**4. Organization branding via existing `Organization#logo_path` / `#cover_path`**
Both already exist (`BlobUrls.url_for(...)`), same pattern used for `logo` in `add-mobile-me-organizations`. `name` is a direct attribute read.

**5. Controller renders 404 via `not_found`, already defined in `Api::V1::Mobile::BaseController`**
No new error-handling code needed — `rescue_from ActiveRecord::RecordNotFound, with: :not_found` already exists; the controller can `raise ActiveRecord::RecordNotFound` when the service returns `nil`, or render directly. Either is fine; picking whichever keeps the controller thinnest during implementation.

## Risks / Trade-offs

- [Risk] `:id` could be a non-UUID or a UUID for an unrelated resource type → `Organization.find_by(id:)` returns `nil` safely (no exception), falls through to the same 404 path as "not a member." No special-casing needed.
- [Risk] A unit with an active ownership AND active occupancy for the same person must appear exactly once → covered by design decision 3 (`unit_ids` built from a union of two id sets, single `Unit.where(id: unit_ids)` read).
- [Trade-off] Returning `404` for both "organization doesn't exist" and "user isn't a member" is intentional (non-disclosure) but means legitimate users mistyping an id get the same response as an authorization failure — acceptable per the confirmed decision; no UX cost since mobile clients drive `:id` from the `/me` organizations list, never free-typed.

## Migration Plan

No data migration. Single deploy: new route, controller, service, tests. Rollback is a plain revert.

## Open Questions

None outstanding — authorization posture (404) and unit role representation (`is_owner` + `occupancy_type`) were resolved during exploration.
