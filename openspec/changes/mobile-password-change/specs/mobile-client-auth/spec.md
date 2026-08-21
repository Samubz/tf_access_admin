## ADDED Requirements

### Requirement: Authenticated password change endpoint
The system SHALL provide `PATCH /api/v1/mobile/auth/password`, requiring a valid authenticated user (the default `authenticate_user!` gate applies; no `skip_before_action`). The endpoint SHALL accept `current_password`, `password`, and `password_confirmation`. It SHALL verify `current_password` against the authenticated user's stored credentials, require `password` and `password_confirmation` to match, and require `password` to satisfy the existing password complexity rule before updating the user's credentials.

#### Scenario: Successful password change
- **WHEN** an authenticated user submits `PATCH /api/v1/mobile/auth/password` with a correct `current_password` and a `password`/`password_confirmation` pair that match and satisfy the complexity rule
- **THEN** the system responds `200 OK` with `data.token`, `data.token_type`, `data.expires_in`, and `data.user` containing `id`, `email`, and `name`
- **AND** the user's password is updated
- **AND** the returned `data.token` is valid for subsequent authenticated requests

#### Scenario: Incorrect current password
- **WHEN** an authenticated user submits `PATCH /api/v1/mobile/auth/password` with a `current_password` that does not match their stored credentials
- **THEN** the system responds `422 Unprocessable Entity` with a generic password-update-failed error
- **AND** the user's password is not changed

#### Scenario: New password and confirmation do not match
- **WHEN** an authenticated user submits `PATCH /api/v1/mobile/auth/password` with a correct `current_password` but `password` and `password_confirmation` that differ
- **THEN** the system responds `422 Unprocessable Entity` with a generic password-update-failed error
- **AND** the user's password is not changed

#### Scenario: New password fails complexity rules
- **WHEN** an authenticated user submits `PATCH /api/v1/mobile/auth/password` with a correct `current_password` and a matching `password`/`password_confirmation` pair that does not satisfy the password complexity rule
- **THEN** the system responds `422 Unprocessable Entity` with a generic password-update-failed error
- **AND** the user's password is not changed

#### Scenario: Error response does not reveal which check failed
- **WHEN** any failure scenario above occurs
- **THEN** the error response body contains only a single generic error message
- **AND** the response does not include field-specific validation details (e.g. it does not distinguish "current password wrong" from "confirmation mismatch" from "complexity failed")

### Requirement: Password change invalidates previously issued tokens
The system SHALL reject, on any subsequent authenticated request, a JWT that was issued before the authenticated user's most recent successful password change. A successful password change SHALL issue a new JWT that is valid immediately.

#### Scenario: Token issued before a password change is rejected afterward
- **WHEN** a user authenticates with a JWT issued before their most recent successful password change, and calls any protected `api/v1/mobile/*` endpoint
- **THEN** the system responds `401 Unauthorized`

#### Scenario: Token issued by the password change itself remains valid
- **WHEN** a user calls a protected `api/v1/mobile/*` endpoint using the `data.token` returned by a successful `PATCH /api/v1/mobile/auth/password` response
- **THEN** the request is authenticated normally

#### Scenario: Users who have never changed their password are unaffected
- **WHEN** a user who has never changed their password via this endpoint authenticates with any validly issued JWT
- **THEN** the request is authenticated normally, regardless of when the token was issued
