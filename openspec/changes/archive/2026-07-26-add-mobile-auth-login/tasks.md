## 1. i18n

- [x] 1.1 Add `api.errors.account_deactivated` key to `config/locales/es.yml`, `config/locales/en.yml`, and `config/locales/pt.yml`, alongside the existing `api.errors.*` keys (`invalid_credentials`, `unconfirmed_account`, etc.).

## 2. Mobile base controller

- [x] 2.1 Create `app/controllers/api/v1/mobile/base_controller.rb`: `Api::V1::Mobile::BaseController < ActionController::API`, including `Devise::Controllers::Helpers` and `Pundit::Authorization`. Do not include `ActsAsTenant::ControllerExtensions` or `RequestSubdomain`.
- [x] 2.2 Add private JSON error helpers mirroring `Api::V1::BaseController` (`forbidden`, `unauthorized`, `not_found` — only the ones this change needs), reusing the same `I18n.t("api.errors.*")` keys.

## 3. Mobile login endpoint

- [x] 3.1 Add routes in `config/routes.rb`: `namespace :mobile { namespace :auth { post :login, to: "sessions#create" } }` nested under `namespace :api { namespace :v1 { ... } }`, alongside the existing `namespace :auth`.
- [x] 3.2 Create `app/controllers/api/v1/mobile/auth/sessions_controller.rb`: `Api::V1::Mobile::Auth::SessionsController < Api::V1::Mobile::BaseController`, action `create`:
  - Look up `User.find_by(email: params[:email])`.
  - `valid_password?(params[:password])` → 401 `invalid_credentials` on failure.
  - `confirmed?` → 401 `unconfirmed_account` if false.
  - `deactivated_at.present?` → 401 `account_deactivated` if true.
  - `client_global?` → 403 `forbidden` if false.
  - `sign_in(user, store: false)` (no `Current.organization`, no `ActsAsTenant.with_tenant`).
  - Render `{ data: { token, token_type, expires_in, user: { id, email, name } } }` on success, using `request.env[Warden::JWTAuth::Hooks::PREPARED_TOKEN_ENV_KEY]` for the token (500 `token_dispatch_failed` if absent, matching the tenant controller's guard).
- [x] 3.3 Register the new path in `config/initializers/warden_jwt_api_routes.rb`: add `[ "POST", %r{\A/api/v1/mobile/auth/login(\.json)?\z} ]` to `config.dispatch_requests` (append, do not replace the existing tenant-login tuple).

## 4. Tenant login: account-deactivation gate

- [x] 4.1 In `app/controllers/api/v1/auth/sessions_controller.rb#create`, add the `deactivated_at.present?` check (401 `account_deactivated`), placed with the existing `confirmed?` check.

## 5. Tests

- [x] 5.1 Create `test/controllers/api/v1/mobile/auth/sessions_controller_test.rb` covering: successful login with no subdomain/tenant set (asserts response body has no `role` key and no tenant/organization side effects), invalid credentials, unconfirmed account, deactivated account, and a confirmed/active user who lacks the global `client` role (403).
- [x] 5.2 Update `test/controllers/api/v1/auth/sessions_controller_test.rb` to add a case: a `tenant_admin` user with `deactivated_at` set is rejected with 401.

## 6. Validation

- [x] 6.1 Run the new and updated test files (`bin/rails test test/controllers/api/v1/mobile/auth/sessions_controller_test.rb test/controllers/api/v1/auth/sessions_controller_test.rb`).
- [x] 6.2 Run `graphify update app`.
