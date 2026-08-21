## Why

The mobile app's `GET /api/v1/mobile/me` currently returns only `email`, `name`, and `dni`. Mobile clients need to know which organizations the authenticated user belongs to and how many units they're linked to in each, to drive organization selection and unit-scoped views in the app.

## What Changes

- `GET /api/v1/mobile/me` response gains `data.organizations`: an array of `{ id, name, units_count }` for every organization where the user has a `Person` with an active membership (`organization_membership.status` in `active`/`invited`).
- `units_count` per organization is the count of distinct units the person is linked to via an active `UnitOwnership` **or** an active `UnitOccupancy` (union, no double-counting a unit held via both).
- Organization roles are explicitly **out of scope** for this change — not included in the response.
- **BREAKING**: `mobile-client-auth`'s existing requirement that `GET /api/v1/mobile/me` "SHALL NOT resolve or expose any organization ... data" is relaxed to allow organization id/name/units_count; role data remains excluded.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `mobile-client-auth`: the "Authenticated user profile endpoint" requirement changes from "SHALL NOT resolve or expose any organization, role, or unit data" to requiring `data.organizations` (id, name, units_count) while still excluding roles.

## Impact

- **Bounded context**: `mobile-client-auth` (API surface change) reaching into `organization-membership` (membership status filter), `unit-owner-management` (`UnitOwnership`), and `unit-occupancy-management` (`UnitOccupancy`) for read-only aggregation. No new capability domain.
- **Affected code**: `app/controllers/api/v1/mobile/me_controller.rb`; likely a small query/service object to assemble `organizations` (reads `User#people`, `Organization`, `OrganizationMembership`, `UnitOwnership`, `UnitOccupancy`); no new tables or columns.
- **Tenant isolation**: mobile sessions run without `ActsAsTenant.current_tenant` set (confirmed in `Api::V1::Mobile::BaseController` / `SessionsController#create`), so the implementation must explicitly wrap tenant-scoped reads (`Person`, `UnitOwnership`, `UnitOccupancy` all `acts_as_tenant :organization`) in `ActsAsTenant.without_tenant`, mirroring the existing pattern in `User#person_for`. No tenant boundary is crossed for any other user — each `Person` row already belongs to exactly one organization, and the response only aggregates the current user's own `Person` records.
- **Authorization**: no new Pundit policy; this is self-service data (the user's own memberships/units), not access to another user's or organization's records.
- **Non-goals**: no role data, no per-unit detail (address, type, etc.) in this endpoint, no pagination (organization count per user is expected to be small), no changes to the login/token endpoints.
- **Dependencies**: none on other in-flight OpenSpec changes.
