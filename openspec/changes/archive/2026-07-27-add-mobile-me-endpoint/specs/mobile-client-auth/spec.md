## ADDED Requirements

### Requirement: Mobile endpoints require authentication by default
The system SHALL require a valid authenticated user (via the mobile-issued JWT) for every `api/v1/mobile/*` endpoint, except `POST /api/v1/mobile/auth/login`, which SHALL remain reachable without authentication.

#### Scenario: Unauthenticated request to a protected mobile endpoint
- **WHEN** a request to a protected `api/v1/mobile/*` endpoint (e.g. `GET /api/v1/mobile/me`) is made with no `Authorization` header, or an invalid/expired JWT
- **THEN** the system responds `401 Unauthorized`

#### Scenario: Login remains reachable without authentication
- **WHEN** `POST /api/v1/mobile/auth/login` is called with no `Authorization` header
- **THEN** the request is processed normally (not rejected for lack of authentication)

### Requirement: Authenticated user profile endpoint
The system SHALL provide `GET /api/v1/mobile/me`, which returns the authenticated user's `email`, `name`, and `dni`. The endpoint SHALL NOT resolve or expose any organization, role, or unit data.

#### Scenario: Authenticated user fetches their profile
- **WHEN** an authenticated user (valid JWT) calls `GET /api/v1/mobile/me`
- **THEN** the system responds `200 OK` with `data.email`, `data.name`, and `data.dni` matching the authenticated user's record
