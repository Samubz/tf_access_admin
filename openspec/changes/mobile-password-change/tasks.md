## 1. Data model

- [x] 1.1 Generate migration adding `password_changed_at:datetime` (nullable) to `users`.
- [x] 1.2 Run migration, update `db/schema.rb`, update the `== Schema Information` annotation block on `app/models/user.rb`.

## 2. Password change + token invalidation logic

- [x] 2.1 In `User`, set `password_changed_at` whenever the encrypted password changes (e.g. `after_update` guarded by `saved_change_to_encrypted_password?`), so any path that changes a password (not just the new endpoint) keeps the timestamp accurate.
- [x] 2.2 Add the `iat` vs `password_changed_at` check to the mobile JWT authentication path — implemented as an override of `JwtDenylist.jwt_revoked?` (the devise-jwt revocation-strategy hook, called for every authenticated request with the decoded payload and resolved user), rather than a `before_action`, since it's the same extension point the app already wires via `jwt_revocation_strategy: JwtDenylist`. Comparison uses whole-second precision on both sides, avoiding the sub-second race noted in design.md. Skipped when `password_changed_at` is `nil`.

## 3. Endpoint

- [x] 3.1 Add route: inspect `config/routes.rb` mobile `auth` namespace (alongside `login`/`logout`) and add `patch :password, to: "passwords#update"`.
- [x] 3.2 Create `Api::V1::Mobile::Auth::PasswordsController < Api::V1::Mobile::BaseController` with `#update`, mirroring `Api::V1::Mobile::Auth::SessionsController#create` for response shape and token issuance.
- [x] 3.3 Implement `#update`: strong-param `current_password`, `password`, `password_confirmation`; call `current_user.update_with_password(password_params)`. Also guards blank `password`/`password_confirmation` up front, since Devise's `update_with_password` otherwise silently no-ops when the new password is blank (it's designed to let profile forms update other fields without changing the password) and `validates_confirmation_of` skips the check entirely when the confirmation value is nil.
- [x] 3.4 On success: initially tried adding the route to `warden_jwt_api_routes.rb` `dispatch_requests` + `sign_in` (the `SessionsController#create` pattern) — reverted, because `Warden::JWTAuth::Strategy#valid?` explicitly refuses to authenticate an incoming token on any path listed in `dispatch_requests` (`!path_is_dispatch_request_path?`), which made the endpoint's own `authenticate_user!` fail. Since this endpoint uniquely needs to both authenticate an incoming token AND mint a new one, it mints the token directly via `Warden::JWTAuth::UserEncoder.new.call(current_user, :user, aud)` (the same primitive `Hooks#add_token_to_env` uses internally for login), called after `update_with_password` succeeds so the new token's `iat` postdates `password_changed_at`. Renders `200 OK` with `data.token`, `data.token_type`, `data.expires_in`, `data.user`.
- [x] 3.5 On failure: renders `422 Unprocessable Entity` with the single generic error key regardless of which `user.errors` key is present.

## 4. i18n

- [x] 4.1 Add `api.errors.password_update_failed` to `config/locales/es.yml`, `en.yml`, and `pt.yml`, following the existing `api: errors:` nesting used by `invalid_credentials`.

## 5. Tests

- [x] 5.1 Controller/request test: successful password change — correct `current_password`, matching + complexity-valid new password → `200`, response shape matches login, password actually updated (verify via `valid_password?` with new password), `password_changed_at` updated.
- [x] 5.2 Controller/request test: wrong `current_password` → `422`, generic error, password unchanged.
- [x] 5.3 Controller/request test: `password`/`password_confirmation` mismatch → `422`, generic error, password unchanged.
- [x] 5.4 Controller/request test: new password fails `PASSWORD_COMPLEXITY` → `422`, generic error, password unchanged.
- [x] 5.5 Controller/request test: unauthenticated request (no/invalid JWT) → `401`.
- [x] 5.6 Controller/request test: token issued before a successful password change is rejected (`401`) on a subsequent protected request (e.g. `GET /api/v1/mobile/me`).
- [x] 5.7 Controller/request test: the `data.token` returned by the password-change response itself authenticates successfully on a subsequent protected request.
- [x] 5.8 Model/unit test: user who never changed their password authenticates normally regardless of token age (`password_changed_at` is `nil`) — implemented as `JwtDenylist#jwt_revoked?` unit tests (`test/models/jwt_denylist_test.rb`) since that's the method owning this behavior.

## 6. Verification

- [x] 6.1 Run the focused Minitest files covering the new controller, the `User` model change, and the mobile auth flow — 20 runs, 0 failures (11 new + 9 existing mobile auth/me tests, no regressions).
- [x] 6.2 Run RuboCop on changed files — 8 files inspected, no offenses.
