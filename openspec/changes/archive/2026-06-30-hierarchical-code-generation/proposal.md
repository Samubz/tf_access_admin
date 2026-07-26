## Why

`ResidentialProperty` and `PropertySection` expose an optional internal `code` field, but today it is only set when the user types one. That leaves most records without a stable machine-readable key, which blocks reliable cross-system references (bulk import placement by section, integrations, exports). `Unit` has no `code` column — only a human-facing `identifier` (`"101"`, `"4B"`) and a `normalized_identifier` used for uniqueness and search — so there is no aligned machine key across the full hierarchy.

We need a single, server-side derivation strategy that always assigns `code` from **hierarchy + type + name** (property/section) or **hierarchy + normalized_identifier** (unit). Human `identifier` on units stays user/import-driven; `normalized_identifier` is aligned to the same transliterating slug rules used for property and section codes.

## What Changes

- Introduce a shared derivation module (`DomainCodes::*`) for slugging, type abbreviations, and collision-safe assignment.
- **ResidentialProperty**: always derive `code` on create as `{property_type_abbrev}-{name_slug}` with org-scoped collision suffixes (`-2`, `-3`…).
- **PropertySection**: always derive `code` on create:
  - root: `{property_code}-{section_type_abbrev}-{name_slug}`
  - child: `{parent_code}-{name_slug}`
- **Unit** (Option B — identifier humano, code máquina):
  - Add nullable `units.code` column.
  - Align `Units::NormalizeIdentifier` so `normalized_identifier` is derived via `DomainCodes::Slug` (transliteration — e.g. `"Área 4"` → `"area-4"`); uniqueness comparisons use `normalized_identifier`.
  - Always derive `code` on create as `{section_code}-{normalized_identifier}` or `{property_code}-{normalized_identifier}`.
  - Human `identifier` presentation unchanged; wizard step 3, bulk import, and search contracts unchanged.
- Wire derivation into create services (`Properties::*`, `PropertySections::Create`, `PropertySections::CreateBatch`, `Units::Create`) — not model callbacks alone.
- Strip `code` from all user-facing strong parameters; client-submitted `code` is never persisted.
- Remove `code` inputs from property/section forms; remove `code` column from wizard summary — users see only human `identifier` for units.
- Codes remain immutable after create (no auto-update on rename, identifier change, or section move); override only via Rails console.
- Purge all residential properties and **every record referencing those `residential_property_id` values** (visits, ownerships, staff, incidents, etc.) — dev/test data only; no backfill rake.

## Capabilities

### New Capabilities

- `hierarchical-code-generation`: Canonical rules and services to derive `ResidentialProperty#code`, `PropertySection#code`, and `Unit#code` from hierarchy, type, name, and normalized unit identifiers.

### Modified Capabilities

- `residential-property`: `code` is always system-derived on create; not user-editable.
- `property-section`: `code` is always system-derived on create; not user-editable.
- `unit`: New `code` column; `normalized_identifier` via `DomainCodes::Slug`; human `identifier` unchanged; `code` derived from `normalized_identifier`.
- `manual-structure-builder`: Remove `code` input from section modals; backend assigns codes.

## Impact

- **Bounded context:** Residential Properties, Property Sections, Units.
- **Models / tables:** `residential_properties.code`, `property_sections.code` — behavior only. `units.code` — **new column** + tenant-scoped partial unique indexes (sectioned and root-level contexts).
- **Services (new):** `DomainCodes::Slug`, `DomainCodes::TypeAbbrev`, `DomainCodes::DerivePropertyCode`, `DomainCodes::DeriveSectionCode`, `DomainCodes::DeriveUnitCode`, `DomainCodes::CollisionResolver`.
- **Services (modified):** `Properties::Create`, `Properties::InitializeDraft`, `PropertySections::Create`, `PropertySections::CreateBatch`, `Units::Create`, `Units::NormalizeIdentifier`.
- **Frontend:** Remove `code` inputs from `ManualSectionForm.vue`, `residential_property/Form.vue`, `StructureForm.vue`. Remove `code` column from `Step4Summary.vue` (units show `identifier` only). Expose `unit.code` read-only in serializers/API only. Wizard step 3 unchanged.
- **Data migration:** Full dependent purge rake (dev/test only) before deploy; then `add_column :units, :code` + indexes. No backfill.
- **Tenant isolation:** Derivation scoped per `organization_id`; collision checks use tenant-scoped indexes.

## Non-goals

- Changing human `identifier` input behavior, wizard step 3 automatic generation, or bulk import column contracts.
- Bulk-import per-row `section_code` resolution (follow-up change).
- Auto-update codes on rename, identifier change, or move after creation.
- UI path to edit codes (console only).
- Making `code` NOT NULL (nullable; derived on every create going forward).
- Backfill rake for existing records (test data is purged instead).
