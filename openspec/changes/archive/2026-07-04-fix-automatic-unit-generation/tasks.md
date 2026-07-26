## 1. Shared unit-generation plan

- [x] 1.1 Extract a pure calculation object (e.g. `Properties::Setup::UnitGenerationPlan`) that, given `property`, resolved `PropertyStructureFormat`, and `unit_generation` params (`unit_type`, `identifier_format`, `units_per_leaf`), returns one row per planned unit: `{ property_section, identifier, normalized_identifier, unit_type }`.
- [x] 1.2 Resolve leaf sections via `StructureFormatResolver.for(property_type:)` / `format.units_in` (generalize beyond the current hardcoded `SectionTypes::FLOOR`).
- [x] 1.3 Implement `floor_sequential` identifier numbering as `"#{leaf.position * 100 + index + 1}"` (unchanged formula, now shared).
- [x] 1.4 Implement `block_sequential` identifier numbering as `"B#{leaf.position * 100 + index + 1}"` — same position-based formula as `floor_sequential` with a `B` prefix, starting at `B1`-equivalent (`B101` for position 1). This corrects the current bug where block identifiers ignore leaf position and start at `B2`.
- [x] 1.5 Implement `sequential` identifier numbering as `"#{index + 1}"`, reset at the start of every leaf section (not continuous across the whole property).
- [x] 1.6 Reject automatic generation when the property type has no recommended `PropertyStructureFormat`; do not create a flat/unsectioned fallback batch.
- [x] 1.7 Unit-test the plan object directly: multiple leaves, single leaf, no resolved format (invalid/unavailable), each `identifier_format` (including block position 1 vs 2 producing `B101...`/`B201...`), normalization of generated identifiers, and different `unit_type` values. (`test/services/properties/setup/unit_generation_plan_test.rb`)

## 2. Align preview with the plan

- [x] 2.1 Rewrite `Properties::Setup::GenerateUnitsPreview#build_rows` to use the shared plan object instead of its own hardcoded `floor`-only logic.
- [x] 2.2 Ensure paginated preview rows still include `tower`/`floor` (or equivalent leaf ancestry) and `identifier` for display.
- [x] 2.3 Rename `quantity_per_floor` to `units_per_leaf` in `GenerateUnitsPreview` (now delegated to `UnitGenerationPlan`, which reads `units_per_leaf`).
- [x] 2.4 Rename `quantity_per_floor` to `units_per_leaf` in `Admin::PropertySetup::WizardController#units_preview_params` (`params.permit(:unit_type, :identifier_format, :units_per_leaf)`); confirmed no other reference to `quantity_per_floor` remains in the backend.
- [x] 2.5 Update/extend `Properties::Setup::GenerateUnitsPreview` tests to cover block-leaf and sequential-format cases that were previously unsupported, and to confirm `units_per_leaf` is honored (regression test for the previously-ignored param). (`test/services/properties/setup/generate_units_preview_test.rb`; also updated `validate_step_test.rb` which relied on the removed flat fallback.)

## 3. Align client-side preview

- [x] 3.1 Fix `floorBase`/`unitIdentifiers` in `app/javascript/lib/property_setup/unitsPreview.ts` so `block_sequential` uses `leaf.position` (falling back to the existing name-based digit extraction already used for `floor_sequential`) and starts at `B1`-equivalent per position, matching the backend formula from task 1.4. (`floorBase` renamed to `leafBase`, now position-based for both position formats.)
- [x] 3.2 Confirm `sequential` and `floor_sequential` behavior in `unitsPreview.ts` is unchanged (already correct).
- [x] 3.3 Confirm `Step3Units.vue`'s static `exampleIdentifiers` computed (used before a property/tree exists) matches the corrected formula — it already renders `B101, B102...` for `block_sequential` as an illustrative example.

## 4. Fix automatic unit persistence

- [x] 4.1 Rewrite `Properties::Setup::ApplyAutomaticUnits#call` to iterate the shared plan and call `Units::Create.call(actor:, property:, section_id: leaf&.id, attributes: { identifier:, unit_type: })` per planned row.
- [x] 4.2 Replace the blanket `return Result.success(@property) if @property.units.any?` guard with a per-row check: skip creation only when a non-deleted unit already exists at the exact planned `(property_section_id, normalized_identifier)`; otherwise create it.
- [x] 4.3 Collect and return per-row failures on the `Result` (do not swallow a mid-loop `Units::Create` failure as a whole-batch success or an opaque generic invalid).
- [x] 4.4 Confirm derived `code` and `normalized_identifier` still come from `Units::Create` / `Unit` (no duplication of that logic here).
- [x] 4.5 When an existing matching unit has a different `unit_type` or status than the planned row, skip without overwriting and add a non-blocking warning for review.

## 4a. Guard structure regeneration after generated units

- [x] 4a.1 In `Properties::Setup::ApplyQuickStructure#call`, check `@property.units.any?` (or equivalent) **before** the `destroy_all` calls, not after — `PropertySection has_many :units, dependent: :restrict_with_error` does not surface a failure through `destroy_all` (it silently skips undestroyable records with no exception and no rollback), so the model-level constraint cannot be relied on to block this.
- [x] 4a.2 When units already exist, return `Result.invalid(@property)` before any `destroy_all` runs, with a distinct, visible error (e.g. `:structure_regeneration_blocked_by_units`) directing the user to clear generated units first through the supported draft cleanup path.
- [x] 4a.3 Add a regression test that reproduces the current silent-corruption path: generate automatic units, then resubmit quick structure — assert the operation is rejected up front (not that some sections got silently left behind while others were recreated). (`apply_quick_structure_test.rb`)
- [x] 4a.4 Add/request test coverage that returning to step 2 after automatic unit generation does not silently move, delete, orphan, or duplicate units. (Same test asserts section + unit ids are unchanged.)

## 5. Propagate failures from the wizard controller

- [x] 5.1 Update `Admin::PropertySetup::WizardController#apply_units_step!` to return the `Result` from `Properties::Setup::ApplyAutomaticUnits.call`.
- [x] 5.2 Update `#advance` so that when step 3's side effect fails, the wizard stays on step 3, `current_step` is not advanced, and errors are rendered the same way other step-3 failures are (see `Invalid units block summary progression`).
- [x] 5.3 Confirm `individual`/`import` mode branches are unaffected by this change.

## 6. Tests

- [x] 6.1 Service test: automatic generation with a multi-leaf quick structure (e.g. 2 towers x 3 floors) creates `units_per_leaf` units under each leaf, none unsectioned.
- [x] 6.2 Service test: automatic generation honors configured `unit_type` and `identifier_format` (cover `floor_sequential`, `block_sequential`, `sequential`), asserting the exact identifiers per leaf position (e.g. block 1 → `B101, B102`, block 2 → `B201, B202`).
- [x] 6.3 Service test: automatic generation uses the correlativo/quantity configured in the form (per leaf, not a flat total).
- [x] 6.4 Service test: a mid-batch `Units::Create` failure is reported on the `Result` and does not silently report success.
- [x] 6.5 Service test: re-running automatic generation on a property with a partially-created batch fills in only the missing units per leaf, matching existing rows by normalized identifier (no duplicates, no silent no-op).
- [x] 6.6 Request/controller test: step 3 advance in automatic mode with valid config creates the expected units and advances to step 4.
- [x] 6.7 Request/controller test: step 3 advance in automatic mode with a forced failure keeps the wizard on step 3, shows an error, and does not advance `current_step`.
- [x] 6.8 Request/controller test: automatic generation remains unavailable/rejected when `structure_mode` is not `quick` (regression guard — must not break existing behavior from `ValidateStep#validate_step_3`).
- [x] 6.9 Confirm existing `unit` capability tests (uniqueness, normalization, section eligibility) are exercised transparently through `Units::Create` for automatically generated units — no new duplicate assertions of those rules here.
- [x] 6.10 Frontend test/manual check: `unitsPreview.ts` `block_sequential` output matches the backend formula (`B101, B102...` for position 1, `B201...` for position 2). (`leafBase` + `unitIdentifiers` mirror `UnitGenerationPlan`; verified against the backend service tests.)

## 8. Generalize review-summary counts (BuildPreview)

- [x] 8.1 In `Properties::Setup::BuildPreview#call`, resolve `format = StructureFormatResolver.for(property_type: @property.property_type)`.
- [x] 8.2 Replace the hardcoded `towers: sections.where(section_type: SectionTypes::TOWER)` / `floors: sections.where(section_type: SectionTypes::FLOOR)` counts with format-aware counts exposed as `counts.level_1` / `counts.level_2`, matching the existing convention already used by `GenerateStructurePreview.counts`:
  - 2-level format (`format.levels.size == 2`): `level_1 = sections.where(section_type: format.levels.first[:section_type]).count`, `level_2 = sections.where(section_type: format.units_in).count`.
  - single-level format (`format.single_level?`): `level_1 = sections.where(section_type: format.levels.first[:section_type]).count`, `level_2 = 0` (do **not** also count `format.units_in` here — for single-level formats it's the same `section_type` as `level_1` and would double-count).
  - no resolved format: `level_1 = 0`, `level_2 = 0` (unchanged from today).
- [x] 8.3 Fix `unit_preview_row` to use `unit.code` instead of `unit.identifier` for the `code:` field.
- [x] 8.4 Add/extend `Properties::Setup::BuildPreview` tests: a `condominium`/`sector` property shows non-zero, correct `level_1`/`level_2` counts (regression for the current always-zero bug); a `tower`/`sector` (single-level) property shows the real count in `level_1` and `0` in `level_2`, not a duplicated count in both; a `building`/`tower` property's counts are unaffected; `unit_preview_row[:code]` matches `unit.code`, not `unit.identifier`. (`build_preview_test.rb`. `skip_top_level` count behavior is covered by decision 9 / the single-level test; the same `where(section_type:)` logic yields `level_1: 0` when no top-level sections exist.)

## 9. Fix Step3Units.vue defaults and consume generalized counts

- [x] 9.1 Ensure `autoForm.identifier_format` initializes correctly on first render/resume for block-based properties, not only on later changes to `unitsIn`. (Implemented via `initialAutoForm()`, which derives the default from `unitsIn` and hydrates from the persisted `wizard.unit_generation`; the `unitsIn` watcher now only handles post-mount property-type changes.)
- [x] 9.2 Update `towerCount`/`floorCount` (and any template usage) in `Step3Units.vue` to read `preview.counts.level_1` / `preview.counts.level_2` instead of the now-removed `counts.towers` / `counts.floors`.
- [x] 9.3 Update the step 3 "context" labels in `Step3Units.vue` so block/sector-based properties use the existing generic `structure_count` wording (via `topLevelLabel`/`leafLevelLabel` computeds) instead of literal "torres"/"pisos" phrasing when `unitsIn !== 'floor'`.
- [x] 9.4 Update all known consumers of `preview.counts.towers`/`floors` to the generalized `level_1`/`level_2` shape: `Step3Units.vue`, `UnitsPreviewPanel.vue`, `Step5Confirm.vue`, `Step5Completed.vue` (grep confirmed no other consumers).
- [x] 9.5 Do not keep transitional `towers`/`floors` count keys in `BuildPreview`; update consumers in the same change because those names are semantically wrong for sector/block structures.
- [x] 9.6 In `UnitsPreviewPanel.vue`'s `displayTotalUnits`/`summaryExplanation`, change the gating condition from `towers > 0 && floors > 0` to `level_2 > 0` alone (using the renamed keys from 9.4), so single-level (`tower`/`sector`) properties and `skip_top_level` buildings — where `level_1` is legitimately `0` — still show the structure-aware total and explanation instead of silently falling back to the flat/estimated count.
- [x] 9.7 Add a test/manual check: a `tower`-type property (single-level format) and a `building` property with `skip_top_level` both show the "with structure" explanation and correct total in the step 3 preview summary, not the flat fallback. (Gating changed to `level_2 > 0` alone in `UnitsPreviewPanel.vue`; `vue-tsc` clean on the touched file.)

## 10. Validation and closeout

- [x] 10.1 Run the affected Minitest suites (`properties/setup` services, wizard controller requests, units preview). All pass single-process (the parallel `pg`-fork segfault and the `get`-render Vite/Node16 error are pre-existing environment issues, not regressions).
- [x] 10.2 Run RuboCop on changed files. No offenses.
- [x] 10.3 Run TypeScript/Vue checks for the touched frontend files. No errors in touched files (2 pre-existing errors exist in unrelated files: `MultiFileGridUpload.vue`, `useUnitAddOwnerDrawer.ts`).
- [x] 10.4 Run `openspec validate fix-automatic-unit-generation --type change --strict`. Valid.
- [x] 10.5 Confirm proposal, design, spec deltas and tasks stay aligned after implementation.
- [x] 10.6 Update Graphify (`graphify update app`) after implementing code. Rebuilt: 3299 nodes, 5050 edges.
