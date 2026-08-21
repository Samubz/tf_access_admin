## Why

Mobile clients can list their organizations (`GET /api/v1/mobile/me`) but have no way to fetch a single organization's details or the units the user is linked to within it — needed to drive the organization-selected view in the app (branding + "my units" list).

## What Changes

- New endpoint `GET /api/v1/mobile/organization/:id`, authenticated (reuses the existing `mobile-client-auth` "Mobile endpoints require authentication by default" requirement — no spec change needed there).
- Returns `data.name`, `data.cover`, `data.logo` for the organization, and `data.residential_properties`: one entry per `ResidentialProperty` in that organization where the authenticated user has at least one linked unit (active `UnitOwnership` and/or active `UnitOccupancy`).
- Each residential property entry: `id`, `name`, `property_type`, `address` (`address_line`, `city`, `region`), and `units` — one entry per unit within that property where the user's `Person` has an active `UnitOwnership` and/or an active `UnitOccupancy`, unioned, not duplicated when both apply to the same unit.
- Each unit entry: `id`, `code`, `display_name`, `unit_type`, `is_owner` (boolean), `occupancy_type` (raw `OccupancyTypes` value, or `null` when the person has no active occupancy on that unit).
- Residential properties with none of the user's units are omitted entirely (not returned as empty-`units` entries).
- Authorization: if the authenticated user has no `Person` with an active or invited `organization_membership` in the requested organization, the endpoint responds `404 Not Found` (does not confirm the organization exists) — same non-disclosure posture as tenant isolation elsewhere in the app.

## Capabilities

### New Capabilities
- `mobile-organization-detail`: `GET /api/v1/mobile/organization/:id` — organization branding + the authenticated user's active units within it, membership-gated.

### Modified Capabilities
(none — this reuses the existing generic "mobile endpoints require authentication" requirement from `mobile-client-auth` as-is)

## Impact

- **Bounded context**: `mobile-organization-detail` (new API surface) reads from `Organization` (branding), `organization-membership` (authorization gate), `unit` (unit fields), `unit-owner-management` (`UnitOwnership`), `unit-occupancy-management` (`UnitOccupancy`). No new capability domain crosses into admin-web authorization (`Authorization::Resolver`/Pundit `OrganizationPolicy`) — that policy assumes an active tenant/subdomain context that mobile sessions never have, so this endpoint needs its own membership-based gate, mirroring the approach already used for `mobile-client-auth` and the `add-mobile-me-organizations` change.
- **Affected code**: new `app/controllers/api/v1/mobile/organizations_controller.rb` (or similar), new route, a new service object under `app/services/mobile/` following the `Mobile::Me::OrganizationsSummary` pattern (bounded queries, no N+1 per unit/property). No new tables/columns — `Unit`, `ResidentialProperty`, `UnitOwnership`, `UnitOccupancy`, `OrganizationMembership`, `Organization` all already exist with the needed fields.
- **Tenant isolation**: mobile sessions never set `ActsAsTenant.current_tenant` (confirmed for `Api::V1::Mobile::BaseController`). This endpoint must validate membership with `ActsAsTenant.without_tenant`, then explicitly wrap unit/ownership/occupancy reads in `ActsAsTenant.with_tenant(organization)` for the requested `:id` only — never resolve or query another organization's tenant-scoped rows.
- **Authorization**: no Pundit policy reused (the existing `OrganizationPolicy` targets admin/tenant-admin access, not mobile client self-service); the membership check documented above is the sole gate. Returning `404` instead of `403` avoids confirming organization IDs to users outside the tenant.
- **Non-goals**: no pagination of `residential_properties` or `units` (expected counts per user per org are small), no roles in the response, no write operations.
- **Dependencies**: builds directly on the pattern established in the already-archived `add-mobile-me-organizations` change; no other in-flight OpenSpec changes affected.
