## Context

`Api::V1::Mobile::Auth::SessionsController` already handles login/logout for the tenant-less mobile `client` role, issuing JWTs via `sign_in` + `Warden::JWTAuth::Hooks::PREPARED_TOKEN_ENV_KEY` and revoking them via `Devise::JWT::RevocationStrategies::Denylist` (`JwtDenylist`, keyed by `jti`). Both dispatch (issue) and revoke (denylist) are wired in `config/initializers/warden_jwt_api_routes.rb` as **route matchers** (`dispatch_requests` / `revocation_requests`), not as generic "any authenticated action can mint/revoke a token" hooks.

`User` already has everything needed to verify + rotate a password: `devise :database_authenticatable` gives `update_with_password(params)` (validates `current_password`, then `update(password:, password_confirmation:)`), `:validatable` adds `validates_confirmation_of :password`, and the app's own `password_meets_complexity` validation (`PASSWORD_COMPLEXITY` regex) runs on any save that changes `password`.

The gap: `JwtDenylist` only ever gets a row added for the *specific token* used in an explicit logout. There is no concept of "every other token this user currently holds." A password change needs to invalidate all of those in one shot, without knowing their `jti`s.

## Goals / Non-Goals

**Goals:**
- Authenticated user can rotate their own password by proving the current one.
- After a successful change, any JWT issued before the change stops working on the next request that uses it.
- The caller gets a fresh, immediately valid JWT in the same response, so the mobile client doesn't need a second login round-trip.
- Failure responses never reveal which specific check failed (wrong current password vs. confirmation mismatch vs. complexity) — a single generic error.

**Non-Goals:**
- Forgot-password / reset-via-email flow (Devise `:recoverable`) for mobile — separate change.
- Rate limiting / throttling repeated attempts — not addressed here (flagged as an open question below).
- Any change to the tenant/admin web session flow (`Api::V1::Auth::SessionsController`, `Users::SessionsController`).

## Decisions

**1. Route & controller: `PATCH /api/v1/mobile/auth/password` → `Api::V1::Mobile::Auth::PasswordsController#update`**
Mirrors `Auth::SessionsController` placement (same namespace, same base controller inheritance), rather than nesting under `MeController`. Grouping password-related auth endpoints under `auth` keeps room for a future `:recoverable`-based reset flow in the same namespace. Uses the default `authenticate_user!` from `Api::V1::Mobile::BaseController` — no `skip_before_action` needed (unlike `login`).

**2. Password verification & update: delegate to `current_user.update_with_password(password_params)`**
Reuses Devise's own tested logic instead of a hand-rolled `valid_password?` + `update` sequence. `password_params` = `{ current_password:, password:, password_confirmation: }` via strong params. On failure, `user.errors` will contain `:current_password` (blank/invalid), `:password` (confirmation mismatch or complexity), etc. — all of these get collapsed to one generic i18n message before rendering (see Decision 4), so we don't need to distinguish them for the client, only for internal logging if we choose to log `user.errors.details` server-side.

**3. Revoking all prior tokens: `password_changed_at` timestamp compared against JWT `iat`, not a denylist**
Alternatives considered:
- *(a) Track every issued `jti` per user, denylist them all on password change.* Rejected: requires a new join table and hooking every token issuance (not just login) to record its `jti`; more moving parts than the problem needs, and `JwtDenylist` was designed for single-token revocation on logout, not bulk revocation.
- *(b) `password_changed_at` + `iat` comparison (chosen).* Add `password_changed_at:datetime` to `users`, set via an `after_update` callback scoped to `saved_change_to_encrypted_password?` (using `update_column` to avoid re-triggering itself). The check is implemented as an override of `JwtDenylist.jwt_revoked?(payload, user)` — the exact extension point `Devise::JWT::RevocationStrategies::Denylist` already defines and that `UserDecoder#check_valid_user` calls on every authenticated request with the decoded payload and resolved user — rather than a separate `before_action`. It first checks the existing per-jti denylist (logout), then falls back to `payload['iat'].to_i < user.password_changed_at.to_i`. This makes *every* previously issued token stop working on its next use, for O(1) storage cost, without enumerating tokens.
- **Token issuance can't reuse the login route's auto-dispatch mechanism.** The obvious move — add this route to `warden_jwt_api_routes.rb`'s `dispatch_requests` and call `sign_in` again, mirroring `SessionsController#create` — does not work here: `Warden::JWTAuth::Strategy#valid?` is defined as `token_exists? && issuer_claim_valid? && !path_is_dispatch_request_path?`, i.e. it deliberately refuses to authenticate an *incoming* token on any path listed in `dispatch_requests`, since those routes (login) aren't supposed to require one. This endpoint needs both (authenticate the incoming token, then issue a new one), so it mints the token directly via `Warden::JWTAuth::UserEncoder.new.call(current_user, :user, aud)` — the same primitive `Warden::JWTAuth::Hooks#add_token_to_env` uses internally — instead of going through the route-matched dispatch path.
- The freshly issued token is minted *after* `password_changed_at` is set (in the same request), so it naturally passes the check (its `iat` is at or after the cutoff second).
- **Known limitation, whole-second granularity:** `Warden::JWTAuth::TokenEncoder` sets `iat` via `Time.now.to_i` — 1-second resolution, not configurable. A token issued in the *same second* as the password change cannot be reliably classified as old-vs-new from `iat` alone; the strict `<` comparison intentionally favors keeping the just-issued token valid over catching that rare same-second old token. Confirmed in `test/controllers/api/v1/mobile/auth/passwords_controller_test.rb`, which uses `travel 1.second` to make the "old token rejected" scenario deterministic instead of second-boundary-flaky.

**4. Error responses: single generic i18n key, following existing `api.errors.*` convention**
All `update_with_password` failures (invalid current password, mismatched confirmation, complexity violation) render `422 Unprocessable Entity` with `{ error: I18n.t("api.errors.password_update_failed") }` (key name TBD at implementation, added to `es`/`en`/`pt`). This matches the user's explicit requirement to not leak which specific rule failed, and follows the same pattern already used for `invalid_credentials`, `unconfirmed_account`, etc. in `Auth::SessionsController`. Field-level Devise error codes are not serialized into the response body.

**5. Success response shape mirrors login**
`{ data: { token, token_type, expires_in, user: { id, email, name } } }`, status `200 OK` — same fields the client already parses after login, so no new response contract to learn.

## Risks / Trade-offs

- **[Risk] `iat` has whole-second resolution (not configurable — see Decision 3), so a token issued in the same second as the password change can't be reliably classified as pre- or post-change** → Mitigation: accepted as a known limitation; the comparison is strict `<` so it always favors keeping the just-issued token valid rather than risking a false revocation of the response the user is about to receive. A token an attacker obtained in that exact same second would, in the worst case, remain valid for one extra second-boundary — not a meaningful window in practice.
- **[Risk] Every authenticated mobile request now pays one extra comparison (and a `User` reload if `current_user` isn't already loaded) for the `iat` check** → Mitigation: `current_user` is already loaded by `authenticate_user!` for every protected action, so this is a field comparison on an already-fetched record, not an extra query.
- **[Risk] No throttling on repeated wrong-`current_password` attempts** → Mitigation: none in this change; flagged as an open question — existing login endpoint also has no explicit throttling (relies on Devise `:lockable` being absent), so this is consistent with current behavior, not a regression.
- **[Trade-off] `password_changed_at` approach invalidates ALL sessions, including the one that just changed the password** → Intentional and required by the proposal (a fresh token is reissued in the same response to compensate), but means a mobile client must swap its stored token immediately from the response, or its very next request will 401.

## Migration Plan

1. Add migration for `users.password_changed_at:datetime` (nullable; existing users simply never had their password "changed" under this feature, so old tokens remain valid until they naturally expire or the user changes their password for the first time under this feature).
2. Add the `iat` vs `password_changed_at` check to the mobile authentication path — additive, no behavior change for users who have never used the new endpoint (`password_changed_at` is `nil`, check is skipped).
3. Add the new route + controller + i18n keys.
4. No backfill needed; no rollback complexity beyond dropping the column and the route if reverted.

## Open Questions

- Should repeated failed `current_password` attempts be rate-limited or trigger any alerting? Left out of scope for this change but worth a follow-up if abuse is observed.
- Should the generic error key be shared with any future "forgot password" failure states, or kept endpoint-specific? Deferred until that flow is designed.
