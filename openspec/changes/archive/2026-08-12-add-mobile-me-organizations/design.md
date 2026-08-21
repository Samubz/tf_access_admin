## Context

`GET /api/v1/mobile/me` ([app/controllers/api/v1/mobile/me_controller.rb](../../../app/controllers/api/v1/mobile/me_controller.rb)) currently renders `email`, `name`, `dni` directly from `current_user` with no service object. Mobile login (`Api::V1::Mobile::Auth::SessionsController#create`) authenticates any user holding the global `client` role without resolving an organization: no `organization_id` is required, and `Api::V1::Mobile::BaseController` never sets `Current.organization` or `ActsAsTenant.current_tenant`. So by the time `MeController#show` runs, there is no active tenant — `current_user` may have a `Person` (and therefore memberships/units) in several organizations at once.

`User` already has `has_many :people` and `has_many :organizations, through: :people`, but every read through `Person`, `UnitOwnership`, and `UnitOccupancy` is tenant-scoped (`acts_as_tenant :organization`) and will raise/return nothing without an explicit `ActsAsTenant.without_tenant` block — the existing precedent is `User#person_for`.

## Goals / Non-Goals

**Goals:**
- Add `data.organizations` to `GET /api/v1/mobile/me`: array of `{ id, name, units_count }`, one entry per organization where the user has an actively-membered `Person`.
- `units_count` = count of distinct units linked via an active `UnitOwnership` OR an active `UnitOccupancy` for that `Person` (union, not sum).
- Keep the controller thin; put the aggregation in a service object, following the project's `Namespace::Verb` service pattern (e.g. `People::ContextualRoles`).

**Non-Goals:**
- No role data in the response (explicitly descoped by the user during exploration).
- No per-unit detail (unit id/address/type) — only the count.
- No pagination — organization count per mobile client user is expected to be small (single digits).
- No change to login/token issuance, JWT payload, or tenant resolution.
- No new database columns, tables, or indexes beyond what's already indexed (`unit_ownerships`/`unit_occupancies` already have `(organization_id, person_id, status)` indexes).

## Decisions

**1. Service object: `Mobile::Me::OrganizationsSummary.call(user)`**
Returns an array of hashes `{ id:, name:, units_count: }`. Keeps `MeController#show` a thin render, matches existing service-object convention (`People::ContextualRoles`, `Accounts::InvitePerson`), and gives a single, testable unit for the tenant-bypass + aggregation logic.
- *Alternative considered*: inline query in the controller. Rejected — the `ActsAsTenant.without_tenant` + union-count logic is non-trivial enough to warrant isolated unit tests, and controllers in this codebase stay thin.

**2. Membership filter: reuse `active`/`invited`**
Same predicate as `User#member_of_tenant?` (`organization_membership.status.in?(%w[active invited])`), per user decision during exploration. Organizations where the person's membership is `suspended`/other are excluded.

**3. `units_count` computed per-organization via `ActsAsTenant.without_tenant`, single query per relation (not per-person N+1)**
Rather than looping `current_user.people` and issuing two `pluck` queries per person (N+1 across organizations), aggregate in one pass:
```ruby
ActsAsTenant.without_tenant do
  people = current_user.people
    .joins(:organization_membership)
    .where(organization_memberships: { status: %w[active invited] })
    .includes(:organization)

  owned = UnitOwnership.where(person_id: people.map(&:id), status: "active")
    .group(:person_id).distinct.pluck(:person_id, :unit_id)
  occupied = UnitOccupancy.where(person_id: people.map(&:id), status: "active")
    .group(:person_id).distinct.pluck(:person_id, :unit_id)
  # merge into a per-person Set of unit_ids, then size per person
end
```
This bounds the query count to a small constant (people lookup + 2 aggregate queries) regardless of how many organizations the user belongs to.
- *Alternative considered*: one SQL query with `UNION` + `COUNT(DISTINCT unit_id)` grouped by `person_id`. More efficient at scale but harder to read/maintain for an expected small `N`; revisit if a user with dozens of organizations becomes real.

**4. `ActsAsTenant.without_tenant` wraps only the read**
Matches `User#person_for` precedent. No risk of leaking cross-tenant writes since this is a read-only summary and each `Person`/`UnitOwnership`/`UnitOccupancy` row already carries its own `organization_id` — the query filters by `person_id IN (current_user's own people)`, so no other user's or organization's data can be reached even without a tenant scope active.

**5. Spec change is a relaxation, not a new capability**
`mobile-client-auth`'s "Authenticated user profile endpoint" requirement currently states the endpoint "SHALL NOT resolve or expose any organization, role, or unit data." This change updates that requirement to allow organization id/name/units_count while keeping the role exclusion. Handled as a delta spec on the existing `mobile-client-auth` capability (see proposal.md).

## Risks / Trade-offs

- [Risk] A user's `Person` record exists but its `organization_membership` is missing (not just wrong status) → excluded via `INNER JOIN`, same behavior as inactive status. Acceptable: `Person#has_one :organization_membership` should always exist per `Accounts::ProvisionTenantIdentity`, but the join makes the endpoint defensively skip malformed data instead of erroring.
- [Risk] Large number of organizations per user (not expected today, mobile is `client`-role only) → current design does a bounded number of queries, not one-per-org, so it degrades gracefully; only the in-Ruby merge step scales with organization count, which is cheap.
- [Trade-off] Returning `units_count` instead of unit details keeps payload small and avoids exposing unit-level PII (addresses) on a general profile endpoint — matches Non-Goals.

## Migration Plan

No data migration. Deploy is a single controller/service change:
1. Add `Mobile::Me::OrganizationsSummary` service + tests.
2. Update `MeController#show` to include `organizations:`.
3. Update `mobile-client-auth` delta spec and scenario/request tests asserting the new field.
Rollback is a plain revert — no persisted state changes.

## Open Questions

- None outstanding; role exclusion and membership-status filter were resolved during exploration.
