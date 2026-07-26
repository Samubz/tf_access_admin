# Rolify Architecture: Person vs User

## Decision

In this implementation, operational roles are **not** assigned via Rolify directly on the `User` or `Person` models. Instead, we use explicit `StaffAssignment` records with a `residential_property_id` and `staff_type`.

## Rationale

### Person vs User

- **Person** = identity / domain entity representing a natural or legal person in the system
- **User** = authentication subject — a login credential linked to a Person via `user.people` association

A single Person may eventually have multiple Users (e.g., login via email, SSO account, etc.), but in the current implementation it's 1:1 per organization.

### Why not Rolify on User?

1. **Scope isolation**: User roles are global; property-scoped roles require parent resource context. Rolify lacks built-in property scoping.
2. **Multitenancy**: Rolify roles live in a single database table (`roles`, `roles_users`). Scoping to `organization_id` + `residential_property_id` requires custom filtering throughout the codebase.
3. **Auditing**: `StaffAssignment` benefits from the `audited` gem, which tracks all state changes (status, dates). Rolify mutations are harder to audit with detailed context.

### Architecture: StaffAssignment as canonical role source

- `StaffAssignment` is the **single source of truth** for operational roles per property.
- Each assignment has:
  - `person_id`, `organization_id`, `residential_property_id` (scope)
  - `staff_type` (the concrete role: MANAGER, CONCIERGE, CLEANING, etc.)
  - `status` (ACTIVE / INACTIVE)
  - `starts_at`, `ends_at` (validity period)

- `Authorization::Resolver` reads `StaffAssignment.currently_active` scoped to organization and property.
- `Authorization::StaffRoleMapper` normalizes `staff_type` → operational role name (property_admin, concierge, cleaning_staff, internal_staff).
- `People::ContextualRoles` queries `StaffAssignment` to build badge roles for the Person profile.

### Trade-offs

| Aspect | Rolify (not used) | StaffAssignment (used) |
|--------|-------------------|----------------------|
| Scope isolation | ❌ Requires custom filtering per property | ✅ Native `residential_property_id` FK |
| Multitenancy | ⚠️ Shared table, custom org scoping | ✅ Acts-as-tenant partitioning |
| Auditing | ⚠️ Manual or third-party | ✅ `audited` gem tracks all changes |
| Flexibility | ✅ Generic, reusable role system | ⚠️ Purpose-built for this domain |
| Birthday dates | ❌ Not supported | ✅ `starts_at`, `ends_at` built-in |

## Future: Rolify for tenant/org-wide roles

If org-wide roles (e.g., `tenant_admin`, `content_manager`) are later managed via UI, they could use Rolify on User, scoped by `ActsAsTenant.current_tenant`. However, property-scoped roles will remain `StaffAssignment`-based for the isolation guarantees outlined above.

## See also

- `Authorization::Resolver` — how roles are resolved in context
- `Authorization::StaffRoleMapper` — staff_type ↔ role name mapping
- `StaffAssignment` model — the role holder
