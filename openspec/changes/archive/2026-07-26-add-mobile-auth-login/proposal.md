## Why

Client-role users (residents/owners) need to authenticate from the mobile app without a tenant subdomain, since a client can be linked to units across multiple organizations and has no single organization context at login time. Today `POST /api/v1/auth/login` hard-requires resolving an `Organization` from the request subdomain and only admits `tenant_admin`/`super_admin`, so there is no login path a mobile client can use.

## What Changes

- Add `POST /api/v1/mobile/auth/login`, a tenant-less login endpoint scoped to the global `client` role, returning the same response envelope as the tenant login (`token`, `token_type`, `expires_in`, `user`), minus `role` (role-per-organization will be served later by a separate `/me` endpoint).
- Add `Api::V1::Mobile::BaseController`, a lightweight `ActionController::API` base (no `ActsAsTenant`/subdomain concerns) for this and future tenant-less mobile endpoints.
- Register the new login route with `Warden::JWTAuth` dispatch so a JWT is actually issued (dispatch is matched by an exact-path regex, not a route pattern).
- **BREAKING** (behavior, not contract): `Api::V1::Auth::SessionsController#create` (existing tenant login) gains a new rejection case — a deactivated account (`deactivated_at` present) is rejected with 401, mirroring the same check added to the mobile login. Accounts that were previously able to log in while `deactivated_at` was set (a state nothing currently sets, but now enforced) will be rejected.
- Introduce the first enforcement of `users.deactivated_at` anywhere in the app (the column exists today with zero application logic behind it).

## Capabilities

### New Capabilities
- `mobile-client-auth`: tenant-less authentication for the global `client` role — the new `/api/v1/mobile/auth/login` endpoint, its credential/role/account-status gates, and the shared account-deactivation rule it introduces (also applied to the existing tenant login as a supporting change, see Impact).

### Modified Capabilities
_None._ No existing `openspec/specs/**` capability documents `Api::V1::Auth::SessionsController`'s behavior today, so there is no delta spec to author. The deactivation check added there is captured as an implementation task/test (see `tasks.md`), not as a spec delta.

## Impact

- **Routes**: `config/routes.rb` — new `namespace :mobile { namespace :auth { post :login } }` under `api/v1`.
- **Controllers**: new `app/controllers/api/v1/mobile/base_controller.rb`, new `app/controllers/api/v1/mobile/auth/sessions_controller.rb`; modified `app/controllers/api/v1/auth/sessions_controller.rb` (add deactivation check).
- **Config**: `config/initializers/warden_jwt_api_routes.rb` — add the mobile login path to `dispatch_requests`.
- **Models**: no schema/migration changes. Reads existing `User#client_global?`, `User#deactivated_at`, `User#confirmed?`.
- **i18n**: new `api.errors.account_deactivated` key in `config/locales/es.yml`, `en.yml`, `pt.yml`.
- **Tenant isolation**: the new endpoint intentionally never sets `Current.organization` or `ActsAsTenant.current_tenant` — it authenticates a user, not a tenant membership. It does not read or expose any organization-scoped data, so tenant isolation is not weakened; `client_global?` only confirms the user holds the global `client` role somewhere, without selecting or leaking which organization.
- **Tests**: new `test/controllers/api/v1/mobile/auth/sessions_controller_test.rb`; updated `test/controllers/api/v1/auth/sessions_controller_test.rb`.

## Non-goals

- No `/api/v1/mobile/me` or any organization/role listing endpoint (planned as a follow-up change).
- No mobile logout/session revocation endpoint.
- No behavior for `suspended_at` or `global_status` (left unused, as today).
- No mobile-facing resource endpoints beyond auth (e.g. a mobile equivalent of `Api::V1::Private::BaseController`).
