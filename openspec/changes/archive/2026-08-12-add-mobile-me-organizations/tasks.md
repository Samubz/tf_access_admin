## 1. Service object

- [x] 1.1 Add `app/services/mobile/me/organizations_summary.rb` implementing `.call(user)`, returning an array of `{ id:, name:, logo:, units_count: }` hashes.
- [x] 1.5 Add `logo` (via `Organization#logo_path`, `null` when no logo attached) to each organization entry. Covered by unit and request tests.
- [x] 1.2 Wrap the read in `ActsAsTenant.without_tenant`, scoping to `user.people.joins(:organization_membership).where(organization_memberships: { status: %w[active invited] })`, mirroring `User#person_for`.
- [x] 1.3 Compute `units_count` per person as the union of distinct `unit_id`s from active `UnitOwnership` and active `UnitOccupancy`, using a bounded number of queries (not per-person N+1) as outlined in design.md decision 3.
- [x] 1.4 Return organizations ordered consistently (e.g. by `organization.name`) so the response is stable across requests.

## 2. Controller wiring

- [x] 2.1 Update `app/controllers/api/v1/mobile/me_controller.rb#show` to call `Mobile::Me::OrganizationsSummary.call(current_user)` and include `organizations:` in the JSON response alongside `email`, `name`, `dni`.
- [x] 2.2 Confirm no `role` key is present anywhere in the response payload.

## 3. Tests

- [x] 3.1 Unit test `Mobile::Me::OrganizationsSummary`: multiple organizations, `suspended` membership excluded, `active`/`invited` included, union of ownership+occupancy not double-counted, empty result when user has no memberships.
- [x] 3.2 Request test for `GET /api/v1/mobile/me` covering: single org, multiple orgs, zero orgs, and asserting `role` is absent from the payload.
- [x] 3.3 Run the mobile-client-auth focused Minitest file(s) to confirm no regression on existing login/auth scenarios.

## 4. Spec sync

- [x] 4.1 After implementation is verified, sync the `mobile-client-auth` delta spec into `openspec/specs/mobile-client-auth/spec.md` (via `/opsx:sync` or archive flow).
