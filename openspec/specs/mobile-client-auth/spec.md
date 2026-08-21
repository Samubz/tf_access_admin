# mobile-client-auth

## Purpose

TBD

## Requirements

### Requirement: Tenant-less login for the global client role
The system SHALL provide `POST /api/v1/mobile/auth/login`, which authenticates a user by email and password without resolving, requiring, or exposing any `Organization`/tenant context. The endpoint SHALL be reachable regardless of request subdomain (including no subdomain) and SHALL NOT set `Current.organization` or activate `ActsAsTenant.current_tenant`.

#### Scenario: Successful login without a tenant subdomain
- **WHEN** a user with valid credentials and the global `client` role submits `POST /api/v1/mobile/auth/login` with `email` and `password`, from a request with no organization subdomain
- **THEN** the system responds `200 OK` with `data.token`, `data.token_type`, `data.expires_in`, and `data.user` containing `id`, `email`, and `name`
- **AND** the response does not include a `role` field
- **AND** the `Authorization` response header carries the same JWT as `data.token`

#### Scenario: Invalid credentials
- **WHEN** a login is submitted with an email that does not exist, or a password that does not match
- **THEN** the system responds `401 Unauthorized` with the same invalid-credentials error used by the tenant login endpoint

#### Scenario: Account not confirmed
- **WHEN** a user with valid credentials has not confirmed their account
- **THEN** the system responds `401 Unauthorized` with the same unconfirmed-account error used by the tenant login endpoint

#### Scenario: Account deactivated
- **WHEN** a user with valid credentials has `deactivated_at` present
- **THEN** the system responds `401 Unauthorized` with an account-deactivated error, and no JWT is issued

#### Scenario: User lacks the global client role
- **WHEN** a user with valid, confirmed, active credentials does not hold the global `client` role in any organization
- **THEN** the system responds `403 Forbidden`, and no JWT is issued

### Requirement: Account deactivation gate applies to tenant login as well
The system SHALL reject authentication at `POST /api/v1/auth/login` (existing tenant login) for a user whose `deactivated_at` is present, using the same rejection semantics as the mobile login endpoint.

#### Scenario: Deactivated account rejected on tenant login
- **WHEN** a user with valid credentials, a confirmed account, and `deactivated_at` present submits `POST /api/v1/auth/login` with a resolvable organization subdomain
- **THEN** the system responds `401 Unauthorized` with an account-deactivated error, and no JWT is issued

### Requirement: Mobile endpoints require authentication by default
The system SHALL require a valid authenticated user (via the mobile-issued JWT) for every `api/v1/mobile/*` endpoint, except `POST /api/v1/mobile/auth/login`, which SHALL remain reachable without authentication.

#### Scenario: Unauthenticated request to a protected mobile endpoint
- **WHEN** a request to a protected `api/v1/mobile/*` endpoint (e.g. `GET /api/v1/mobile/me`) is made with no `Authorization` header, or an invalid/expired JWT
- **THEN** the system responds `401 Unauthorized`

#### Scenario: Login remains reachable without authentication
- **WHEN** `POST /api/v1/mobile/auth/login` is called with no `Authorization` header
- **THEN** the request is processed normally (not rejected for lack of authentication)

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
