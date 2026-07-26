## Why

Automatic unit generation in the property setup wizard (step 3, quick mode) does not actually create units the way the wizard promises and previews. `Properties::Setup::ApplyAutomaticUnits` ignores the configured `unit_type`, `identifier_format` and the property's leaf sections (towers/floors, sectors/blocks), and instead creates a flat, unsectioned batch of units using hardcoded values. Its result is also discarded by the wizard controller, so partial or total failures never surface to the user — the wizard just advances as if generation succeeded. Users report "no está creando unidades": either literally zero units are created, or units are created in the wrong place (property root instead of under the expected leaf sections) and are invisible in the structure tree.

## What Changes

- Rewrite `Properties::Setup::ApplyAutomaticUnits` to generate units per leaf section (one batch per tower/floor, sector/block, etc.), honoring `unit_generation.unit_type` and `unit_generation.identifier_format`, using the same leaf-resolution logic (`StructureFormatResolver` / `format.units_in`) that the rest of the wizard uses instead of a hardcoded `SectionTypes::FLOOR` check.
- Align `Properties::Setup::GenerateUnitsPreview` with the same leaf-resolution and identifier-format logic so the server-side preview shown to the user in step 3 matches what actually gets persisted.
- Fix `app/javascript/lib/property_setup/unitsPreview.ts` so the instant client-side preview agrees with the corrected backend algorithm: `block_sequential` becomes position-aware (like `floor_sequential`) and starts at `B1` instead of the current position-blind, off-by-one `B2` start.
- Rename `quantity_per_floor` to `units_per_leaf` everywhere on the backend (`GenerateUnitsPreview`, `WizardController#units_preview_params`); the frontend already only ever sends `units_per_leaf`, so today the server-side preview silently ignores the user's configured quantity and always falls back to a default of 4.
- Every generated unit is created through the existing `Units::Create` service with the resolved `property_section_id`, so uniqueness, normalization, section eligibility and authorization continue to be enforced by the existing `unit` capability — no domain rule is duplicated.
- `Admin::PropertySetup::WizardController#apply_units_step!` captures and propagates the `Result` from `ApplyAutomaticUnits`; a failure blocks step advancement and surfaces errors, consistent with how other step-3 failures already behave.
- Replace the blanket "property already has units" idempotency guard with a check that does not mask partial failures from a previous attempt (e.g. re-running only fills in what's missing per leaf, or a stale/partial state is reported as a blocking error rather than silently treated as success).
- Fix the same hardcoded-`TOWER`/`FLOOR` assumption in a third place found during discovery: `Properties::Setup::BuildPreview#call` (drives the step 3/4 review summary) always shows `0` structure counts for `condominium`/`horizontal`/`sector` properties. Counts become format-aware (`level_1`/`level_2`, resolved via `StructureFormatResolver`) instead of hardcoded section types.
- Fix `BuildPreview#unit_preview_row` showing the raw `identifier` in the summary's "code" column instead of the derived `unit.code`.
- Fix `Step3Units.vue`'s `unitsIn` watcher (missing `immediate: true`) so `identifier_format` defaults correctly the first time step 3 renders for a block-based property, not only after `unitsIn` changes.
- No changes to `Unit`, `Units::*` services, or the `unit` capability's rules — this change only fixes how the wizard invokes existing, already-correct domain services.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `property-setup-wizard`: tightens "Step 3 defines how units will be created" so automatic generation is required to create units per leaf section using the configured type/format (not a flat unsectioned batch); tightens "Each step validates before progression" so a failed automatic-generation apply blocks progression and surfaces errors instead of being silently discarded; tightens "Wizard delegates all domain operations to existing services" so every automatically generated unit is explicitly required to go through `Units::Create` with its resolved leaf section; tightens "Step 4 presents an editable review summary" so structure counts and unit codes shown in the summary are correct for every property type with a recommended structure format, not only `floor`/`tower`-based ones.

## Impact

- **Services**: `app/services/properties/setup/apply_automatic_units.rb` (rewritten), `app/services/properties/setup/generate_units_preview.rb` (aligned leaf-resolution logic, `units_per_leaf` param), `app/services/properties/setup/build_preview.rb` (format-aware `counts`, `unit.code` fix).
- **Controllers**: `app/controllers/admin/property_setup/wizard_controller.rb` (`apply_units_step!` / `advance` — capture and surface the `Result`; `units_preview_params` — `units_per_leaf` instead of `quantity_per_floor`).
- **Frontend**: `app/javascript/lib/property_setup/unitsPreview.ts` (`block_sequential` formula corrected to match backend), `app/javascript/components/admin/property_setup/Step3Units.vue` (`unitsIn` watcher `immediate: true`, `counts.level_1`/`level_2` consumption), locale files `es.yml`/`en.yml`/`pt.yml` (step 3 context strings for non-floor formats).
- **No schema, migration, or new service changes.** `Units::Create`, `Unit`, and the `unit` capability are consumed as-is.
- **Tests**: service tests for `Properties::Setup::ApplyAutomaticUnits` and `GenerateUnitsPreview`, request/controller tests for the wizard step 3 advance action covering success, partial failure, and re-run/idempotency cases.
- Dependency: relies on the already-archived `improve-units-foundation`, `improve-units-flow` and `hierarchical-code-generation` changes (Unit model, `Units::Create`, code derivation) — none of that is modified here.
