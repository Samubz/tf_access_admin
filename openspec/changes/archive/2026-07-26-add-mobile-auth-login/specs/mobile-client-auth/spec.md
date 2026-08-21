## ADDED Requirements

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
