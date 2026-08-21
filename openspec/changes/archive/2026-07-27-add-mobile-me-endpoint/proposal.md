## Why

The mobile client app needs to fetch the logged-in user's basic profile after authenticating via `POST /api/v1/mobile/auth/login`. That endpoint (from the archived `add-mobile-auth-login` change) deliberately deferred a `/me` endpoint as future work. This change delivers a minimal first slice: identity fields only, no organization/role/unit data yet.

## What Changes

- Add `GET /api/v1/mobile/me`, returning the authenticated user's `email`, `name`, and `dni`.
- `Api::V1::Mobile::BaseController` gains `before_action :authenticate_user!` — every mobile endpoint is now protected by default.
- `Api::V1::Mobile::Auth::SessionsController#create` (login) explicitly opts out via `skip_before_action :authenticate_user!, only: [:create]`, since it's the one mobile endpoint that must remain public.

## Capabilities

### New Capabilities
_None._ This extends the existing `mobile-client-auth` capability rather than introducing a new one.

### Modified Capabilities
- `mobile-client-auth`: adds a requirement that mobile endpoints require authentication by default (with login as the sole exception), and a requirement for the new `GET /api/v1/mobile/me` endpoint.

## Impact

- **Routes**: `config/routes.rb` — add `get :me, to: "me#show"` inside the existing `namespace :mobile` (sibling to `namespace :auth`).
- **Controllers**: modified `app/controllers/api/v1/mobile/base_controller.rb` (add `authenticate_user!`), modified `app/controllers/api/v1/mobile/auth/sessions_controller.rb` (skip it for login), new `app/controllers/api/v1/mobile/me_controller.rb`.
- **Models**: none. Reads only existing `User#email`, `User#name`, `User#dni`.
- **Tenant isolation**: not applicable — this endpoint never touches `Person`, `Organization`, or any `acts_as_tenant` model; it reads scalar attributes off `current_user` only.
- **Tests**: new `test/controllers/api/v1/mobile/me_controller_test.rb`; existing `test/controllers/api/v1/mobile/auth/sessions_controller_test.rb` serves as the regression check that login still works unauthenticated after the base controller change.

## Non-goals

- No organizations list, no role-per-organization, no unit counts (explicitly deferred to a future change).
- No changes to `Person`, `UnitOwnership`, `UnitOccupancy`, or any tenant-scoped model.
- No new mobile endpoints beyond `/me`.
