## Context

`ResidentialProperty` and `PropertySection` have optional `code` columns with tenant-scoped uniqueness. Values must match `[a-zA-Z0-9-]+` (`AlphanumericHyphenCodeValidatable`). Today codes are only persisted when supplied explicitly.

`Unit` has no `code` column. It uses human-facing `identifier` + `normalized_identifier` (user/import-driven, uniqueness scoped to section context). Wizard step 3, bulk import, and search all depend on `identifier` remaining human-readable.

Existing create paths: `Properties::Create` / `InitializeDraft`, `PropertySections::Create`, `PropertySections::CreateBatch`, `Units::Create`.

## Goals / Non-Goals

**Goals:**

- `DomainCodes::*` as single source of truth for slugging, type abbreviations, collision-safe assignment.
- `code` on property, section, and unit is **always system-derived** on create; users cannot set it via UI or API params.
- `identifier` on unit **unchanged** as human label; `normalized_identifier` aligned to `DomainCodes::Slug` (transliteration).
- Unit `code` derived from `normalized_identifier`, not raw `identifier`.
- Remove `code` from all user-facing strong parameters.
- Remove `code` inputs from property/section forms; UI shows only human `identifier` for units.
- Migration: `add_column :units, :code` + uniqueness index.
- Purge all residential properties and **every dependent record** referencing those IDs — test data only; no backfill.
- Override only via console.

**Non-Goals:**

- Changing wizard step 3 automatic generation or bulk import column contracts.
- Auto-update codes on rename, identifier change, or move.
- Bulk-import `section_code` column resolution (follow-up).
- UI path to edit codes.
- Making `code` NOT NULL.

## Decisions

### D1: `DomainCodes` service namespace (not model callbacks)

| Class | Responsibility |
|-------|----------------|
| `DomainCodes::Slug` | Transliterate + slug: trim, NFKC, downcase, non-alnum → `-`, collapse `-`, max length |
| `DomainCodes::TypeAbbrev` | Map `property_type` / `section_type` → 3-letter abbrev |
| `DomainCodes::CollisionResolver` | Numeric `-2`, `-3` suffix within a scope proc |
| `DomainCodes::DerivePropertyCode` | `{type_abbrev}-{name_slug}` + org collision |
| `DomainCodes::DeriveSectionCode` | Root vs child patterns + section uniqueness scope |
| `DomainCodes::DeriveUnitCode` | `{section_code}-{normalized_identifier}` or `{property_code}-{normalized_identifier}` + unit code uniqueness scope |

### D2: Slug rules

```text
Input:  "Torre Á"     → "torre-a"
Input:  "Torre 123"   → "torre-123"   (no suffix parsing)
Max segment length: 32 chars per slug part; total code max 64
```

### D3: Property code formula

```text
base = "#{TypeAbbrev[property_type]}-#{Slug[name]}"
while taken in organization (non-deleted): candidate = "#{base}-#{n++}"
```

### D4: Section code formula

**Root:** `[property_code, TypeAbbrev[section_type], Slug[name]].compact.join("-")`  
**Child:** `"#{parent_code}-#{Slug[name]}"`  
Collision scope: `(organization, residential_property, parent_id, section_type, code)`.

Property and section codes are derived once from creation-time hierarchy and names. Later renames or moves do not automatically update existing codes.

### D5: Unit normalized_identifier and code (new column)

`Units::NormalizeIdentifier` SHALL derive `normalized_identifier` via `DomainCodes::Slug` on the trimmed human-facing `identifier`. Uniqueness comparisons continue to use `normalized_identifier` (unchanged scope).

Unit `code` is derived **after** normalization, using the persisted `normalized_identifier` segment — not the raw `identifier`:

```text
If property_section present and has code:
  base = "#{section_code}-#{normalized_identifier}"

If no section (root-level unit):
  base = "#{property_code}-#{normalized_identifier}"
```

Example: `identifier: "Área 4"` → `normalized_identifier: "area-4"` → `code: clp-tor-torre-a-piso-1-area-4`.

Collision scope for `code`: `(organization, residential_property, property_section_id, code)` among non-deleted units.

`identifier` presentation stays human (`"Área 4"`, `"101"`). Wizard step 3 unchanged. `Unit#code` MUST NOT auto-update on identifier change or section move.

### D6: `code` is not user-editable — strip from params

Remove `:code` from strong params on all user-facing create/update paths. Create services always derive; client values ignored.

| Controller | Field removed |
|-----------|---------------|
| `wizard_controller` — `step_params`, `batch_section_params`, `section_update_params`, section create params | `:code` |
| `residential_properties_controller` | `:code` |
| `property_sections_controller` | `:code` |
| Unit controllers | `:code` (new column; never in params) |

`identifier` on units **remains in params** — unchanged.

### D7: Override path (console only)

```ruby
unit.update_column(:code, "CORRECTED-CODE")
```

No UI, no rake task for override.

### D8: Remove code input from forms; units show identifier only in UI

- `ManualSectionForm.vue` — remove create and edit `code` inputs
- `residential_property/Form.vue` — remove `code` input
- `property_section/StructureForm.vue` — remove `code` input
- `Step4Summary.vue` — remove the `code` table column; show only `identifier` for units

`unit.code` exposed read-only in serializers/API only (not in user-facing summary tables).

### D9: Migration and full dependent purge (no backfill)

```ruby
# Migration
add_column :units, :code, :string

add_index :units, [:organization_id, :residential_property_id, :property_section_id, :code],
          unique: true,
          where: "deleted_at IS NULL AND property_section_id IS NOT NULL AND code IS NOT NULL",
          name: "idx_units_unique_code_in_section"

add_index :units, [:organization_id, :residential_property_id, :code],
          unique: true,
          where: "deleted_at IS NULL AND property_section_id IS NULL AND code IS NOT NULL",
          name: "idx_units_unique_code_in_property_root"
```

Before deploy, **delete all existing `ResidentialProperty` records and every row in any table that references those `residential_property_id` values** (test data only). A dedicated rake task MUST walk dependents explicitly — not rely on `dependent: :destroy` alone.

Dependent domains to purge (non-exhaustive; task must cover all FK references found in schema):

```
visits, unit_ownerships, unit_occupancies, authorized_residents,
lease_contracts, units, property_sections, property_settings,
staff_assignments, staff_shifts, incidents, announcements,
common_areas, common_area_reservations, parcel_deliveries,
access_events, bulk_imports (nullable FK), notifications (nullable FK)
→ then residential_properties
```

Scope: development / test environments only.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Long codes exceed UI width | Cap at 64 chars; truncate slug segments |
| Unit moves to another section | `code` stays intact (creation-time key); placement change does not re-derive |
| Unit identifier changes after create | Do not auto-update `code`; code remains stable for integrations |
| Purge misses a FK reference | Rake task deletes by `residential_property_id` across all referencing tables before properties |
| `Area 4` vs `Área 4` | Same `normalized_identifier` → duplicate rejected at identifier uniqueness, same code base |

## Migration Plan

1. Run full dependent purge rake (test data).
2. Ship migration (`units.code` + index).
3. Align `Units::NormalizeIdentifier` to `DomainCodes::Slug`.
4. Ship `DomainCodes::*` + create hooks for property, section, unit.
5. Remove `code` from params and form inputs; update Step4Summary.
6. Rollback: drop column; remove service calls.

## Open Questions

- Expose `unit.code` in bulk-import template download? **Defer to bulk-import change.**
