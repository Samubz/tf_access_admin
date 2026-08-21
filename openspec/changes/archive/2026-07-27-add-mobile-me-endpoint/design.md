## Context

`Api::V1::Mobile::BaseController` (introduced in `add-mobile-auth-login`) is currently unauthenticated by default — it was only ever used by the login action, which must stay public. Now that a second mobile endpoint (`/me`) is being added and it must require authentication, the base controller needs an authentication default. Every future mobile endpoint will inherit whatever default is chosen here.

## Goals / Non-Goals

**Goals:**
- Make `Api::V1::Mobile::BaseController` protected by default, with login as the sole explicit exception.
- Serve the three identity fields the mobile app needs today (`email`, `name`, `dni`) with no additional data modeling.

**Non-Goals:**
- Organizations list, per-organization role, unit counts — deferred; see the archived `add-mobile-auth-login` proposal's design.md for the two open questions already surfaced (role semantics: rolify role vs. `People::ContextualRoles`-style domain role; unit-count definition) — those remain unresolved and will need to be revisited when that scope is picked up.
- Any tenant-scoped querying (`Person`, `Organization`, `UnitOwnership`, `UnitOccupancy`) — this change reads only `User` scalar attributes.

## Decisions

### 1. `authenticate_user!` moves to `Api::V1::Mobile::BaseController`, login opts out

Mirrors the existing pattern on the tenant side: `Api::V1::BaseController` applies `before_action :set_current_organization` to everything, and `Api::V1::Auth::SessionsController` (the one action that must run before any org/session exists) uses `skip_before_action ..., only: [:create]` to opt out. Applying the same shape here — `Api::V1::Mobile::BaseController` adds `before_action :authenticate_user!`, and `Api::V1::Mobile::Auth::SessionsController#create` adds `skip_before_action :authenticate_user!, only: [:create]` — means every future mobile controller is protected unless it explicitly says otherwise, which is the safer failure mode (a forgotten `skip` merely makes an endpoint that should be public return 401; a forgotten opt-in would leak data).

**Alternative considered**: add `authenticate_user!` only to `Api::V1::Mobile::MeController`. Rejected — it works for this one endpoint but repeats the "remember to protect every new controller" footgun the base controller was explicitly designed to avoid for tenant concerns in the previous change.

### 2. `MeController#show` reads `current_user` directly, no serializer

The response is three scalar fields with no nesting or conditional logic, so a plain `render json: { data: { email:, name:, dni: } }` matches the style already used by both login controllers (which build their JSON hand rolled rather than through `ActiveModelSerializers`, consistent with `Api::V1::Mobile::BaseController` not including the AMS-based `render_resource` helpers that `Api::V1::BaseController` has). Introducing a serializer for three fields would be premature abstraction; revisit once `/me` grows (e.g. when the organizations list is added).

### 3. No new error handling

`authenticate_user!` failing renders Devise's default 401 (via Warden), the same behavior already relied on by `Api::V1::Private::BaseController` with zero custom `rescue_from`. `Api::V1::Mobile::BaseController` already doesn't override this, and this change doesn't need to either.

## Risks / Trade-offs

- **[Risk] Adding `authenticate_user!` to the base controller is technically a behavior change to the existing login controller's request pipeline.** → Mitigation: `skip_before_action` fully neutralizes it for `:create`; the existing `test/controllers/api/v1/mobile/auth/sessions_controller_test.rb` suite re-run after this change is the regression check (all 5 cases must still pass unauthenticated).
- **[Risk] Scope is intentionally narrow — mobile app may expect the organizations list sooner than a follow-up change delivers it.** → Mitigation: explicitly called out as a non-goal here and in the proposal; no code shortcut is taken that would make adding it later harder (the response shape is a flat `data` object that can grow an `organizations` key without breaking clients that only read `email`/`name`/`dni`).
