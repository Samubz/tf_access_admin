## Context

`Api::V1::Auth::SessionsController#create` (tenant login) always requires an `Organization` resolved from the request subdomain (`RequestSubdomain#get_organization_from_subdomain`), and only admits a user whose `Person` for that organization holds `tenant_admin` (or a `super_admin`). The `client` role, however, is already modeled as global rather than tenant-scoped:

- `AvailableRoles::GLOBAL = [SUPER_ADMIN, CLIENT]` (`app/models/concerns/available_roles.rb`).
- `Role#organization_required_for_non_global_roles` exempts `CLIENT` from needing an `organization_id`.
- `User#client_global?` already exists: `ActsAsTenant.without_tenant { people.any? { |p| p.has_role?(AvailableRoles::CLIENT) } }`.

A client can own/occupy units across multiple organizations (`Person belongs_to :organization`, one `Person` row per org), so there is no single tenant to resolve at login time — the mobile app has no subdomain to send. This design adds a sibling login endpoint that authenticates the user without resolving or requiring any organization.

Separately, `users.deactivated_at` (and `suspended_at`, `global_status`) exist in the schema but are read/written nowhere in `app/`. This change is the first to give `deactivated_at` behavior, applied to both the new mobile login and the existing tenant login (confirmed as in-scope with the user).

## Goals / Non-Goals

**Goals:**
- Authenticate a `client`-role user without any tenant/organization context.
- Reuse the existing JWT issuance mechanism (`devise-jwt` + Warden) and the existing response envelope shape.
- Enforce `confirmed?` and `deactivated_at` consistently on both the mobile and tenant login endpoints.
- Keep the new base controller minimal but positioned as the shared base for future tenant-less mobile endpoints (e.g. a future `/me`).

**Non-Goals:**
- No role-per-organization resolution at login (`role` is omitted from the response; a future `/me` endpoint will list organizations + role per organization).
- No mobile logout/session revocation endpoint.
- No behavior for `suspended_at` or `global_status`.
- No mobile resource endpoints beyond auth (no mobile equivalent of `Api::V1::Private::BaseController` yet).
- No change to how `Api::V1::Private::BaseController` or any other existing controller resolves tenant.

## Decisions

### 1. `Api::V1::Mobile::BaseController` does not inherit from `Api::V1::BaseController`

`Api::V1::BaseController` bakes in `ActsAsTenant::ControllerExtensions`, `set_current_tenant_through_filter`, a class-level `before_action :set_current_organization`, and `RequestSubdomain`. All of that exists to resolve and enforce a tenant, which mobile endpoints explicitly must not do. Inheriting and then skipping the tenant `before_action` (the way `Api::V1::Auth::SessionsController#create` does today) would work for this one action, but every *future* mobile controller would have to remember to skip it too — an easy footgun.

Instead, `Api::V1::Mobile::BaseController` is its own `ActionController::API` subclass, including only `Devise::Controllers::Helpers` (needed for `sign_in`) and `Pundit::Authorization` (kept for consistency with `Api::V1::BaseController` and likely needed by future mobile resource endpoints, even though this change doesn't use it). It defines its own minimal `forbidden`/`unauthorized`/`not_found` JSON helpers mirroring `Api::V1::BaseController`'s, so error shapes stay consistent across `api/v1/*` without sharing tenant machinery.

**Alternative considered**: inherit from `Api::V1::BaseController` and `skip_before_action :set_current_organization` on every mobile action. Rejected — it inverts the safe default (tenant-required unless opted out) for a whole namespace that should never have a tenant, and every new mobile controller/action would need to remember the skip.

### 2. Mobile login looks up the user directly by email, not via `User.find_for_authentication`

`User.find_for_authentication(conditions)` takes an `organization_id` and checks `member_of_tenant?` when present. Mobile has no `organization_id` to pass. Passing `organization_id: nil` already degrades to `find_by(email:)` internally (see `app/models/user.rb:74-89`), so behaviorally it's equivalent — but calling `User.find_by(email: params[:email])` directly in the mobile controller is clearer than relying on that fallback branch of a method whose primary contract is tenant-shaped.

### 3. Role gate: `user.client_global?`, replacing `tenant_admin? || super_admin?`

Mirrors the shape of the existing gate (a boolean check right after password/confirmation) but swaps in the global-role check. `super_admin?` is intentionally **not** also admitted here — this endpoint is for the `client` role specifically per the request; a super admin has no reason to authenticate through the mobile client login.

### 4. Response omits `role`

The tenant login returns `role: ActsAsTenant.with_tenant(organization) { user.tenant_role || user.role }`, which is inherently tenant-scoped. Without a tenant there's nothing correct to compute here (a client's role can legitimately differ — in practice it's always `client`, but expressing that per-organization is the job of the future `/me` endpoint, not this one). Omitting the field rather than hardcoding `"client"` avoids baking in an assumption the `/me` endpoint may need to refine later (e.g. if a client is also staff in some org).

### 5. `deactivated_at` check added to both login paths, `suspended_at`/`global_status` left untouched

The user confirmed only `deactivated_at` should gate login for now. Since it's net-new behavior with no existing pattern to mirror, the check is a simple `return unauthorized if user.deactivated_at.present?`, placed alongside the existing `confirmed?` check in both controllers. `suspended_at` and `global_status` remain fully unused, as they are today — introducing meaning for them is out of scope and would require a decision on their relationship to `deactivated_at` that hasn't been made.

### 6. Warden JWT dispatch registration

`config/initializers/warden_jwt_api_routes.rb` matches dispatch by an exact-path regex, not by Rails route introspection:

```ruby
config.dispatch_requests = [ [ "POST", %r{\A/api/v1/auth/login(\.json)?\z} ] ]
```

The mobile login path is added as a second tuple in the same array (not a replacement):

```ruby
config.dispatch_requests = [
  [ "POST", %r{\A/api/v1/auth/login(\.json)?\z} ],
  [ "POST", %r{\A/api/v1/mobile/auth/login(\.json)?\z} ]
]
```

Without this, `request.env[Warden::JWTAuth::Hooks::PREPARED_TOKEN_ENV_KEY]` is `nil` after `sign_in`, and the controller's existing `token_dispatch_failed` guard fires — the failure mode is a 500, not a silently missing field, so this is easy to catch in the endpoint's own tests but must not be forgotten.

## Risks / Trade-offs

- **[Risk] Retrofitting `deactivated_at` onto the existing tenant login changes production behavior for that endpoint.** → Mitigation: the column has never been set by any code path, so no existing account is currently in a state this check would newly reject; risk is theoretical today but the change is still called out explicitly in the proposal and covered by a dedicated test on the existing controller test file.
- **[Risk] `Api::V1::Mobile::BaseController` duplicates a few lines of error-rendering helpers instead of sharing `Api::V1::BaseController`'s.** → Mitigation: the duplication is ~3 small `render json:` methods; acceptable to keep the tenant and tenant-less controller hierarchies fully decoupled. If it grows, extract a shared concern (e.g. `Api::V1::JsonErrors`) at that point rather than now.
- **[Risk] A `client_global?` user with zero active `Person`/unit relationships in any org can still obtain a token.** → Mitigation: out of scope for this change — `client_global?` checks role assignment, not active occupancy/ownership; any such gating belongs to whichever endpoint exposes org-scoped data (the future `/me` or resource endpoints), not to login.

## Open Questions

None outstanding — role semantics, account-status gating, and controller inheritance were resolved during exploration with the user.
