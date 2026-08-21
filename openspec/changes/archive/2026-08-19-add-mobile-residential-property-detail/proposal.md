## Why

Mobile clients can fetch an organization's branding plus the residential properties/units the user belongs to (`GET /api/v1/mobile/organization/:id`), but have no way to drill into a single residential property to fetch just the units the user owns or rents there — needed for a property-detail screen in the mobile app.

## What Changes

- New endpoint `GET /api/v1/mobile/organization/:organization_id/residential_property/:id`, authenticated (reuses the existing `mobile-client-auth` "Mobile endpoints require authentication by default" requirement — no spec change needed there).
- Returns the requested residential property's `id`, `name`, `property_type`, `address` (`address_line`, `city`, `region`), and `units`: one entry per unit within that property where the authenticated user's `Person` has an active `UnitOwnership` and/or an active `UnitOccupancy` — unioned, not duplicated when both apply to the same unit.
- Each unit entry: `id`, `code`, `display_name`, `unit_type`, `is_owner` (boolean), `occupancy_type` (raw `OccupancyTypes` value, or `null` when the person has no active occupancy on that unit).
- Only units with `status` in `[available, occupied]` (`UnitStatuses::AVAILABLE`, `UnitStatuses::OCCUPIED`) are eligible to appear, regardless of the user's ownership/occupancy status on them.
- Only a residential property with `status == PropertyStatuses::ACTIVE` is eligible to be returned.
- Unified `404 Not Found` response (no distinguishing status code or body) for every one of: the organization doesn't exist, the user has no active/invited membership in it, the residential property doesn't exist (or doesn't belong to that organization), the property's status isn't `active`, or the user ends up with zero eligible units in that property after all filters — same non-disclosure posture as `GET /api/v1/mobile/organization/:id`.

## Capabilities

### New Capabilities
- `mobile-residential-property-detail`: `GET /api/v1/mobile/organization/:organization_id/residential_property/:id` — a single residential property's identity/address plus the authenticated user's active units within it, membership- and status-gated.

### Modified Capabilities
(none — this reuses the existing generic "mobile endpoints require authentication" requirement from `mobile-client-auth` as-is)

## Impact

- **Bounded context**: `mobile-residential-property-detail` (new API surface) reads from `Organization` (authorization root), `organization-membership` (authorization gate), `ResidentialProperty` (identity/address/status), `Unit` (unit fields/status), `UnitOwnership`, `UnitOccupancy`. No new capability domain crosses into admin-web authorization (`Authorization::Resolver`/Pundit `OrganizationPolicy`) — same reasoning as the already-archived `add-mobile-organization-detail`: that policy assumes an active tenant/subdomain context mobile sessions never have.
- **Affected code**: new `app/controllers/api/v1/mobile/organizations/residential_properties_controller.rb`, new nested route under the existing `namespace :mobile` block, a new service object under `app/services/mobile/` mirroring `Mobile::Organizations::Detail` (bounded queries, no N+1). No new tables/columns — `Organization`, `ResidentialProperty`, `Unit`, `UnitOwnership`, `UnitOccupancy`, `OrganizationMembership` all already exist with the needed fields.
- **Tenant isolation**: mobile sessions never set `ActsAsTenant.current_tenant`. `:organization_id` must be validated against the user's own memberships with `ActsAsTenant.without_tenant` before any tenant-scoped read runs; `:id` (the residential property) is then resolved and read only inside `ActsAsTenant.with_tenant(organization)` for that organization, so a property id from a different organization can never leak through — the tenant-scoped lookup simply returns nothing for it.
- **Authorization**: no Pundit policy reused, same rationale as the archived change. The membership check plus property/unit status filters described above are the sole gate; the endpoint always returns `404` rather than `403` or a `200` with an empty payload, unifying every failure mode into one non-disclosure response.
- **Non-goals**: no pagination of `units` (expected count per user per property is small), no property section detail, no roles in the response beyond `is_owner`/`occupancy_type`, no write operations, no distinguishing 404 causes in the response body.
- **Dependencies**: builds directly on the pattern established in the already-archived `add-mobile-organization-detail` (2026-08-19); no other in-flight OpenSpec changes affected.
