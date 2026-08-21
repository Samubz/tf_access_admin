## Why

The mobile API currently has no way for an authenticated user to change their own password — only Devise's web-facing recovery flow exists. Mobile clients need a self-service password change endpoint that requires proof of the current password (not just a valid session) before rotating credentials.

## What Changes

- Add `PATCH /api/v1/mobile/auth/password`, authenticated (uses the default `authenticate_user!` from `Api::V1::Mobile::BaseController`), accepting `current_password`, `password`, `password_confirmation`.
- Verify `current_password` and apply the new password via Devise's `update_with_password`, which also enforces confirmation match (`:validatable`) and the app's existing `PASSWORD_COMPLEXITY` rule.
- On success, invalidate all previously issued JWTs for that user and issue a fresh one in the response (same shape as login: `token`, `token_type`, `expires_in`, `user`).
- Add a `password_changed_at` timestamp on `User`, set on every successful password change, and check it during JWT authentication so tokens issued before the change are rejected — since the existing `JwtDenylist`/`Warden::JWTAuth` route-based dispatch/revocation only covers the login/logout routes, not this new endpoint.
- All failure cases (wrong current password, confirmation mismatch, complexity violation) return a single generic i18n error — no field-specific Devise/ActiveModel error detail in the response, to avoid leaking which check failed.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `mobile-client-auth`: adds a new requirement for an authenticated password-change endpoint, and a new requirement that JWTs issued before a password change are rejected on subsequent requests.

## Bounded context

- Domain: Authentication & Authorization (mobile API surface only; no web/Devise-controller changes).
- Integration points: `Api::V1::Mobile::BaseController` (auth gate), `Warden::JWTAuth` / `JwtDenylist` (token lifecycle), `User` model (Devise `:database_authenticatable`, `:validatable`).
- No tenant-scoped data is touched — this operates on `current_user` only, no `organization_id` scoping concerns.

## Impact

- **Models**: `User` — new `password_changed_at` column + migration.
- **Controllers**: new `Api::V1::Mobile::Auth::PasswordsController`.
- **Routes**: `config/routes.rb` — new route under `namespace :mobile do namespace :auth do ... end end`.
- **Auth pipeline**: JWT validation path (Warden strategy or a `before_action` in the mobile base controller) gains an `iat` vs `password_changed_at` check.
- **i18n**: new generic error key(s) in `es`, `en`, `pt` locale files (`api.errors.*`).
- **Non-goals**: forgot/reset-password (Devise `:recoverable`) web or mobile flow is out of scope for this change; no changes to the admin/web session controllers or `Api::V1::Auth::SessionsController`.
