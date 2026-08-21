## 1. Mobile authentication default

- [x] 1.1 In `app/controllers/api/v1/mobile/base_controller.rb`, add `before_action :authenticate_user!`.
- [x] 1.2 In `app/controllers/api/v1/mobile/auth/sessions_controller.rb`, add `skip_before_action :authenticate_user!, only: [:create]`.

## 2. `/me` endpoint

- [x] 2.1 Add `get :me, to: "me#show"` inside `namespace :mobile` in `config/routes.rb`, alongside the existing `namespace :auth`.
- [x] 2.2 Create `app/controllers/api/v1/mobile/me_controller.rb`: `Api::V1::Mobile::MeController < Api::V1::Mobile::BaseController`, action `show`, rendering `{ data: { email: current_user.email, name: current_user.name, dni: current_user.dni } }` with status `:ok`.

## 3. Tests

- [x] 3.1 Create `test/controllers/api/v1/mobile/me_controller_test.rb`: authenticated request returns 200 with correct `email`/`name`/`dni`; unauthenticated request returns 401.
- [x] 3.2 Run `test/controllers/api/v1/mobile/auth/sessions_controller_test.rb` as a regression check that login still works unauthenticated after the base controller change.

## 4. Validation

- [x] 4.1 Run the new and existing mobile test files (`bin/rails test test/controllers/api/v1/mobile/me_controller_test.rb test/controllers/api/v1/mobile/auth/sessions_controller_test.rb`).
- [x] 4.2 Run `graphify update app`.
