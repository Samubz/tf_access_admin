## MODIFIED Requirements

### Requirement: Authenticated user profile endpoint
The system SHALL provide `GET /api/v1/mobile/me`, which returns the authenticated user's `email`, `name`, `dni`, and `organizations`. `organizations` SHALL be an array with one entry per organization where the user has a `Person` record with an active membership (`organization_membership.status` in `active` or `invited`), each entry containing `id`, `name`, `logo`, and `units_count`. `logo` SHALL be the organization's logo URL (via `Organization#logo_path`), or `null` when the organization has no logo attached. `units_count` SHALL be the count of distinct units the person is linked to via an active `UnitOwnership` or an active `UnitOccupancy` in that organization (union, not sum, of the two relations). The endpoint SHALL NOT resolve or expose any role data.

#### Scenario: Authenticated user fetches their profile
- **WHEN** an authenticated user (valid JWT) calls `GET /api/v1/mobile/me`
- **THEN** the system responds `200 OK` with `data.email`, `data.name`, `data.dni` matching the authenticated user's record, and `data.organizations` as an array

#### Scenario: User belongs to multiple organizations
- **WHEN** the authenticated user has a `Person` with an active membership in more than one organization
- **THEN** `data.organizations` contains one entry per such organization, each with `id`, `name`, `logo`, and `units_count`
- **AND** no `role` field is present anywhere in the response

#### Scenario: Organization has no logo attached
- **WHEN** the authenticated user's organization has no logo attached
- **THEN** that organization's `logo` field is `null`

#### Scenario: Organization membership is not active
- **WHEN** the authenticated user has a `Person` in an organization whose `organization_membership.status` is neither `active` nor `invited` (e.g. `suspended`)
- **THEN** that organization is excluded from `data.organizations`

#### Scenario: Units counted as a union of ownership and occupancy
- **WHEN** the authenticated user's `Person` in an organization has an active `UnitOwnership` and an active `UnitOccupancy` on the same unit, plus an active `UnitOwnership` on a second unit
- **THEN** that organization's `units_count` is `2`, not `3` (the shared unit is not double-counted)

#### Scenario: User has no organizations
- **WHEN** the authenticated user has no `Person` record with an active membership in any organization
- **THEN** `data.organizations` is an empty array
