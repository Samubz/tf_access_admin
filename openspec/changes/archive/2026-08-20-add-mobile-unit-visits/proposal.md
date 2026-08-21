## Why

Mobile clients can already drill down to organization → residential property → the units a resident belongs to, but have no way to fetch the actual visits scheduled for a specific unit on a given day — needed for a "today's visits" screen for residents.

## What Changes

- New endpoint `GET /api/v1/mobile/residential_property/:id/unit/:unit_id/visitas`, authenticated (reuses the existing `mobile-client-auth` "Mobile endpoints require authentication by default" requirement — no spec change needed there).
- Accepts an optional `day` query parameter (`YYYY-MM-DD`); defaults to "today" computed in the residential property's own timezone (`ResidentialProperty#timezone`), not the server's. An invalid `day` format responds `422 Unprocessable Entity`.
- Returns an array of visits scheduled for that unit on that day: `[{ visitor_name, checked_in_at, checked_out_at, status }]`. All `VisitStatuses::ALL` values are included (no status filtering) — the resident sees the full day, not just "currently active" visits.
- Authorization gate distinct from the two prior mobile endpoints: the authenticated user must have an **active `UnitOccupancy`** on the requested unit — active `UnitOwnership` alone (owner without occupancy) does NOT grant access. Every failure mode (organization/property/unit not found, property or unit not eligible, no active occupancy) responds identically `404 Not Found`.
- Unlike the two prior mobile endpoints, an empty result (no visits scheduled that day) responds `200 OK` with an empty array — a day with no visits is a normal, expected state, not a signal of a stale link.

## Capabilities

### New Capabilities
- `mobile-unit-visits`: `GET /api/v1/mobile/residential_property/:id/unit/:unit_id/visitas` — the visits scheduled for a unit on a given day, gated to the unit's active resident (occupancy-only).

### Modified Capabilities
(none — this reuses the existing generic "mobile endpoints require authentication" requirement from `mobile-client-auth` as-is)

## Impact

- **Bounded context**: `mobile-unit-visits` (new API surface) reads from `ResidentialProperty` (tenant bootstrap + status gate), `Unit` (status gate, property membership), `UnitOccupancy` (the sole authorization signal), `Visit` (the data returned), `Person` (`visitor_person` for `visitor_name`). No new capability domain crosses into `Residents::VisitContext` / `Authorization::Resolver` — that pattern grants `create_visits`/`authorize_visits` capabilities for the write-side private API and is a heavier check than reading a resident's own unit's visit log requires.
- **Affected code**: new `app/controllers/api/v1/mobile/residential_properties/units/visits_controller.rb`, new nested route under the existing `namespace :mobile` block, a new service object under `app/services/mobile/` mirroring `Mobile::Organizations::ResidentialProperties::Detail`. No new tables/columns — `Organization`, `ResidentialProperty`, `Unit`, `UnitOccupancy`, `Visit`, `Person` all already exist with the needed fields; `Visit` already has an `(organization_id, unit_id, scheduled_at)` index that serves this query directly.
- **Tenant isolation**: mobile sessions never set `ActsAsTenant.current_tenant`, and unlike the two prior mobile endpoints this route carries no `:organization_id` path param at all — only `:id` (residential property) and `:unit_id`. The organization is bootstrapped from an untrusted, tenant-unscoped `ResidentialProperty` lookup (`ActsAsTenant.without_tenant`), then every subsequent read (the property itself, the unit, the occupancy, the visits) is re-resolved inside `ActsAsTenant.with_tenant(organization)` — the untrusted lookup is never used for anything beyond discovering which tenant to open.
- **Authorization**: no Pundit policy reused, same rationale as the two prior mobile endpoints (admin/tenant-admin context that doesn't exist for mobile sessions). Deliberately narrower than those two endpoints' "ownership ∪ occupancy" union — here only active `UnitOccupancy` counts, per explicit product decision that a non-resident owner should not see a unit's visit log through this endpoint.
- **Non-goals**: no pagination (small expected volume per unit/day), no visit creation/authorization (already covered by `POST /api/v1/private/units/:unit_id/visits`), no authorizer/unit/property data in the response body (only `visitor_name`, `checked_in_at`, `checked_out_at`, `status`), no roles, no write operations.
- **Dependencies**: builds directly on the patterns established in the already-archived `add-mobile-organization-detail` and `add-mobile-residential-property-detail` (both 2026-08-19); no other in-flight OpenSpec changes affected.
