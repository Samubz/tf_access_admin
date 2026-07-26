## Context

Property setup wizard step 3, "automatic" mode, is meant to generate one batch of units per leaf section of the structure created in step 2 (quick mode only), honoring `unit_generation.unit_type`, `unit_generation.identifier_format` and a per-leaf quantity (`units_per_leaf` / `quantity_per_floor`). The leaf level is defined per property type by `Properties::Setup::StructureFormatCatalog` (`PropertyStructureFormat#units_in`, e.g. `floor` for buildings/towers, `block` for condominiums/horizontal/sector).

Today three implementations of "identifier format" disagree with each other, and a fourth path never reads the user's configured quantity at all:

- `app/javascript/lib/property_setup/unitsPreview.ts` (client-side preview rendered instantly as the user types) implements `floor_sequential` as `leaf.position * 100 + index + 1`, but `block_sequential` as a flat `B${1 + index + 1}` — fixed base of 1 regardless of block position, and an off-by-one that makes the first identifier `B2` instead of `B1`. `sequential` resets to `1, 2, 3...` per leaf (this one is correct/clean).
- `Properties::Setup::GenerateUnitsPreview` (server-side preview, `/units_preview` endpoint) only special-cases `floor_sequential` (`floor.position * 100 + index`, hardcoded to `section_type: SectionTypes::FLOOR`); every other format — including `block_sequential` — falls through to a flat, section-less list starting at `1`. It also reads the quantity from `@params.fetch(:quantity_per_floor, 4)`, but the controller's `units_preview_params` only permits `:quantity_per_floor`, while the frontend (`usePropertySetupUnitsPreview.ts`) sends `units_per_leaf` in the querystring. That parameter is silently dropped: the server-side preview always computes with the default of `4`, no matter what the user configures.
- `Properties::Setup::ApplyAutomaticUnits` (drives the actual persistence on `advance`) does not use leaves, `unit_type`, or `identifier_format` at all. It creates `count` root-level units (`property_section: nil`) with hardcoded `unit_type: apartment` and identifiers `101..100+count`, treating the leaf quantity as a flat total.
- `Admin::PropertySetup::WizardController#apply_units_step!` calls `ApplyAutomaticUnits.call` without capturing the `Result`, so a raised authorization error or a mid-loop `Units::Create` failure never blocks step advancement.

This produces the reported symptom ("no está creando unidades"): either the wizard silently advances with zero/partial units, or units exist but are unsectioned and invisible in the structure tree the user expects to see them in. It also means the three surfaces the user interacts with (instant client preview, server preview, actually persisted units) can each show a different number and shape of units for the same configuration.

**Resolved during exploration (see `openspec/changes/fix-automatic-unit-generation` discovery thread):**
- `block_sequential` is corrected, not replicated as-is: it becomes position-aware and starts at 1, mirroring `floor_sequential` exactly but with a `B` prefix (`B{leaf.position * 100 + index + 1}`, first identifier `B101`). The existing `B2`-first, position-blind behavior in `unitsPreview.ts` is a bug, not a spec.
- `quantity_per_floor` is retired everywhere in the backend in favor of `units_per_leaf`, matching what the frontend already sends and what the `property-setup-wizard` spec already names.

A **third occurrence of the same hardcoded-`TOWER`/`FLOOR` bug** was found in `Properties::Setup::BuildPreview#call` ([build_preview.rb:25-30](app/services/properties/setup/build_preview.rb:25)), which drives the step 3/4 review summary shown via `Admin::PropertySetup::WizardSerializer#preview_json`. Its `counts` hash counts sections by `section_type: SectionTypes::TOWER` / `SectionTypes::FLOOR` directly, so a `condominium`/`horizontal`/`sector` property (whose sections are `sector`/`block`, not `tower`/`floor`) always shows `0` for both counts in the summary regardless of its real structure. Two smaller, adjacent bugs were found alongside it:
- `BuildPreview#unit_preview_row` sets `code: unit.identifier` instead of `code: unit.code`, so the review summary's "code" column shows the raw identifier rather than the derived hierarchical code.
- `Step3Units.vue`'s `watch(() => props.unitsIn, ...)` (used to default `autoForm.identifier_format`) lacks `{ immediate: true }`, so opening or resuming step 3 on an already-block-based property leaves `identifier_format` defaulted to `floor_sequential` — a value that isn't even offered in that property's format dropdown.

All three are in scope for this change: they are the same root defect (assuming `floor`/`tower` are the only possible leaf/top-level section types) surfacing in a third file, discovered while fixing the first two.

## Goals / Non-Goals

**Goals:**
- One shared piece of logic resolves "leaf sections + identifiers to generate" from `(property, format, unit_generation params)`, used identically by the server-side preview and the apply step, so what the user previews is what gets persisted.
- The client-side instant preview (`unitsPreview.ts`) is brought into agreement with the server-side algorithm for `block_sequential` (position-aware, starts at 1) so all three surfaces (client preview, server preview, persisted units) show the same identifiers for the same configuration.
- `ApplyAutomaticUnits` creates one unit per generated identifier, in its resolved leaf section, via `Units::Create`, honoring the configured `unit_type`.
- Support the three documented `identifier_format` values (`floor_sequential`, `block_sequential`, `sequential`) generically across leaf types, not just `floor`.
- `units_per_leaf` is the single canonical parameter name for generation quantity across frontend and backend; `quantity_per_floor` is removed.
- A failed apply (partial or total) is visible to the user and blocks step advancement — no silent success.
- Re-running the apply step (e.g. user goes back and forward) does not duplicate units nor silently no-op over a partially-generated batch.
- The step 3/4 review summary (`BuildPreview`) reports correct, non-zero structure counts for every property type with a recommended `PropertyStructureFormat`, not only `building`/`tower`/`residential_complex`, and shows the real derived `unit.code` instead of the raw identifier.
- Step 3's automatic-mode form defaults `identifier_format` correctly on first render for any property type, not only when `unitsIn` changes after mount.

**Non-Goals:**
- No changes to `Unit`, `Units::Create`/`Update`/`MoveToSection`/etc., or the `unit` capability's validation/uniqueness/normalization rules.
- No changes to bulk import or single/individual unit creation modes.
- No new database columns, migrations, or broad persistence services. The only new object is a pure `UnitGenerationPlan` calculator shared by preview and apply; this otherwise fixes existing services (`GenerateUnitsPreview`, `ApplyAutomaticUnits`, `BuildPreview`), one controller action/params method, and the frontend files identified above (`unitsPreview.ts`, `Step3Units.vue`, `usePropertySetupUnitsPreview.ts` if the param rename requires it, `Step2Structure.vue` only if it also reads `counts.towers`/`floors`).
- No change to `GenerateStructurePreview`'s or `ApplyQuickStructure`'s leaf/level *resolution* logic — it already works correctly via `format.levels`. The only change to `ApplyQuickStructure` is the pre-`destroy_all` guard in decision 5a; its structure-generation algorithm is untouched.
- No change to the "automatic only in quick mode" gating already enforced in `ValidateStep#validate_step_3`.
- No change to `floor_sequential`'s existing formula (`floor.position * 100 + index + 1`) — it was already correct and consistent between frontend and backend.

## Decisions

**1. Extract a shared `Properties::Setup::UnitGenerationPlan` (or similar) building block used by both the preview and the apply step.**
Both `GenerateUnitsPreview` and `ApplyAutomaticUnits` need the same list of `{ property_section, identifier, unit_type }` rows. Rather than duplicating leaf-resolution and identifier-format logic in two services (the current bug), extract it once. Alternative considered: keep both services independent and just fix each in parallel — rejected, since that's exactly how they drifted apart the first time, and it would leave both places to sever tests to catch.

**2. Resolve leaves via `StructureFormatResolver.for(property_type:)` / `format.units_in`, not a hardcoded `SectionTypes::FLOOR`.**
`@property.property_sections.where(section_type: format.units_in)` generalizes to `block` (condominium/horizontal/sector) and any future leaf type, instead of only supporting `floor`. If no recommended format is resolved, automatic generation is unavailable and returns a step-level error; no flat/unsectioned fallback is used for automatic mode.

**3. Identifier formats (confirmed during exploration):**
- `floor_sequential`: `identifier = "#{leaf.position * 100 + index_within_leaf + 1}"` — unchanged, already correct and already matches both frontend and backend today (e.g. floor 1 → `101, 102, 103...`; floor 2 → `201, 202...`).
- `block_sequential`: `identifier = "B#{leaf.position * 100 + index_within_leaf + 1}"` — same position-based formula as `floor_sequential`, with a `B` prefix (e.g. block 1 → `B101, B102...`; block 2 → `B201, B202...`). This **corrects** the existing `unitsPreview.ts` behavior, which today ignores `leaf.position` (flat base of 1 for every block) and starts at `B2` instead of `B1` — both are being treated as bugs, not preserved as intentional behavior.
- `sequential`: plain `index_within_leaf + 1`, reset to `1` at the start of every leaf section (not continuous across the whole property) — matches the existing, already-correct `unitsPreview.ts` behavior for this format.
All three formats produce `units_per_leaf` units per leaf section; only the identifier numbering strategy changes per format.

**4. `ApplyAutomaticUnits` creates each unit via `Units::Create.call(actor:, property:, section_id: leaf.id, attributes: { identifier:, unit_type: })`.**
This keeps `Units::Create` as the single source of truth for normalization, uniqueness, section eligibility and code derivation — nothing about the `unit` capability changes.

**5. Idempotency: compare what's already persisted per leaf against the plan instead of a blanket `@property.units.any?` guard.**
For each planned `(section_id, normalized_identifier)` pair, skip creation only if a matching non-deleted unit already exists in that exact placement; otherwise create it. The match uses the same normalization as `Units::Create` (`Units::NormalizeIdentifier` / `normalized_identifier`), not the raw visible identifier. If an existing matching unit has a different `unit_type` or status, automatic generation skips it, records a non-blocking warning, and does not overwrite it. This lets a retried/resumed wizard fill in what's missing rather than either duplicating or silently no-op'ing over a partial run. Alternative considered: wrap the whole batch in a transaction and roll back entirely on any failure — rejected as a first-pass fix because a single invalid row (e.g. a stray duplicate) would still block the rest of an otherwise-valid batch; the per-row skip-if-exists approach is simpler and matches how bulk import already tolerates partial batches.

**5a. Changing quick structure after generated units exist is guarded — and the guard must run *before* `ApplyQuickStructure`'s `destroy_all`, not rely on the model layer to stop it.**
Once automatic units have been generated for a draft property, the wizard must not silently regenerate, move, or delete them when the user returns to step 2. If a step 2 quick-structure change would replace/remove sections while units exist, the change is blocked until the generated units are explicitly cleared through the supported draft cleanup path.

**Discovered mechanism (why this isn't just a nice-to-have):** `PropertySection has_many :units, dependent: :restrict_with_error`, so on paper a leaf section with units "can't be destroyed." But `ApplyQuickStructure#call` destroys sections via bare `@property.property_sections.where(...).destroy_all`, not through `PropertySections::Destroy`. `destroy_all` calls `.destroy` on each record and does not raise or check the boolean result when `restrict_with_error` blocks one — Rails silently skips that record and moves to the next, with no rollback of the surrounding transaction. Concretely: if leaf sections already have generated units, `destroy_all` destroys every *unit-less* section (e.g. the top-level tower rows, or unrelated empty floors) while silently leaving unit-bearing leaf sections in place, and `ApplyQuickStructure` proceeds to create a brand-new set of sections anyway — the draft ends up with a mix of stale, unit-bearing old sections and fresh new ones, `WizardState` still reports `structure_mode: "quick"` success, and nothing is surfaced to the user. The fix must check `@property.units.any?` (or equivalent) **before** attempting `destroy_all` and reject the whole operation with a visible `Result.invalid`, rather than trusting `restrict_with_error` to fail loudly — it doesn't, under `destroy_all`.

**6. Controller captures and surfaces the `Result`.**
`apply_units_step!` returns the `Result` from `ApplyAutomaticUnits.call`; `advance` checks it the same way it already checks `ValidateStep` — on failure, redirect back to step 3 with errors and do not advance `current_step`.

**7. Retire `quantity_per_floor`; `units_per_leaf` is the only parameter name.**
`units_per_leaf` already flows end-to-end from the form (`Step3Units.vue`), through the client preview, through the advance/apply payload (`unit_generation.units_per_leaf`) — `quantity_per_floor` only exists in `GenerateUnitsPreview` and `WizardController#units_preview_params`, and was never actually reachable from the frontend. Replace both with `units_per_leaf`; no compatibility shim is needed since the old name was effectively dead on the request path.

**8. Fix `unitsPreview.ts` to match the corrected `block_sequential` formula.**
Since decision 3 corrects `block_sequential` rather than replicating its current bug, `floorBase`/`unitIdentifiers` in `app/javascript/lib/property_setup/unitsPreview.ts` must be updated in lockstep (use `leaf.position`, drop the `+1` base offset) so the instant client-side preview keeps matching the server-side preview and the persisted result. This is a small, contained change to the same two functions already touched by the identifier-format logic — not a new frontend surface.

**9. `BuildPreview#call` resolves top-level/leaf counts the same way `GenerateUnitsPreview`/`ApplyAutomaticUnits` now do — via `StructureFormatResolver`, not hardcoded `SectionTypes::TOWER`/`FLOOR`.**
Counts are keyed `level_1`/`level_2` (top level / leaf level), reusing the naming `GenerateStructurePreview.counts` already established, instead of inventing a new key scheme.

- When `format.levels.size == 2`: `level_1` counts `sections.where(section_type: format.levels.first[:section_type])` (top level); `level_2` counts `sections.where(section_type: format.units_in)` (leaf level). This is correct even when the property used `skip_top_level` (a "no towers" `building`), because counting is by `section_type` present in the DB, not by tree depth: `level_1` naturally comes out `0` (no top-level sections exist) while `level_2` still reflects the real floor count.
- When `format.single_level?` (`format.levels.size == 1`, e.g. `tower`/`sector` property types, whose one level *is* `units_in`): `level_1` counts that level's `section_type`; `level_2` is always `0`. This mirrors `GenerateStructurePreview.counts` exactly (`single_level_nodes` only produces `depth: 1` nodes, so its own `level_2` is already `0` for these formats) — **discovered edge case**: naively computing `level_2` from `format.units_in` regardless of `single_level?` would double-count the same sections into both `level_1` and `level_2`, since for a single-level format `levels.first[:section_type] == units_in`.
- When the property type has no recommended format, both are `0` (unchanged from today's behavior for those types).

Alternative considered: keep the `towers`/`floors` key names but source them from the resolved format — rejected because a condominium's sectors/blocks would then be mislabeled as "towers"/"floors" in the JSON and in the UI copy, which is confusing even once the *count* is correct; renaming forces the UI copy to be fixed too instead of leaving a numerically-correct-but-mislabeled summary.

**9a. Any "does this property have a valid structure to generate units into" check gates on `level_2 > 0` alone, never `level_1 > 0 && level_2 > 0`.**
`UnitsPreviewPanel.vue`'s `displayTotalUnits`/`summaryExplanation` today require both `towers > 0 && floors > 0` before showing the "with structure" explanation and the `level_2 * units_per_leaf` estimate; otherwise it silently falls back to a flat/estimated count. Because `level_1` is legitimately `0` for single-level formats and for `skip_top_level` buildings (per decision 9), that condition must become `level_2 > 0` alone — otherwise those two legitimate cases would never show the correct structure-aware total, even though a valid leaf structure exists.

**10. `unit_preview_row` uses `unit.code`, not `unit.identifier`, for the `code:` field.**
One-line fix; `unit.code` is the already-derived hierarchical code (`hierarchical-code-generation`), which is what the review summary's "code" column is meant to show.

**11. `Step3Units.vue`'s `unitsIn` watcher runs `immediate: true`.**
`autoForm.identifier_format` must reflect the property's actual leaf type as soon as step 3 renders, not only after `unitsIn` changes post-mount. This is consistent with the other `immediate: true` watcher already present in the same file (`props.errors`).

## Risks / Trade-offs

- [Risk] Generalizing identifier formats to non-floor leaves changes previewed/generated identifiers for condominium/horizontal/sector property types that previously got the flat fallback. → Mitigation: this is a bug fix bringing behavior in line with the already-documented spec (`property-setup-wizard` requirement text already says identifier rules apply to any `units_in` leaf); add explicit test coverage per property type.
- [Risk] Correcting `block_sequential` (position-aware, starts at `B1`) changes what any user currently mid-wizard on a condominium/horizontal/sector draft has already seen in the client preview. → Mitigation: `ApplyAutomaticUnits` was never functional for this case (units were unsectioned/wrong regardless), so no already-persisted unit identifiers are being renumbered — only the not-yet-submitted preview changes.
- [Risk] Per-row skip-if-exists idempotency could mask a genuine identifier collision as "already generated" if a leftover unit from an unrelated manual edit happens to match. → Mitigation: match on exact `(section_id, normalized_identifier)`, and surface a warning when a matched unit has different type/status; no existing unit is overwritten.
- [Risk] Shared extraction (`UnitGenerationPlan`) touches both preview and apply paths at once. → Mitigation: cover both with service-level tests before wiring the controller change; keep the extraction minimal (pure calculation, no persistence) so it's easy to unit test in isolation.
- [Risk] Renaming `BuildPreview.counts.towers/floors` → `counts.level_1/level_2` is a breaking shape change for consumers of that JSON besides `Step3Units.vue`. → Mitigation: update all known consumers in the same change (`Step3Units.vue`, `UnitsPreviewPanel.vue`, `Step5Confirm.vue`, `Step5Completed.vue`, `Step4Summary.vue`, and `Wizard.vue` if related counts are consumed); no compatibility keys are retained because `towers`/`floors` are semantically wrong for sector/block structures.
- [Risk] Returning to step 2 after automatic units were generated can leave units attached to obsolete sections or prevent section deletion. → Mitigation: block destructive quick-structure regeneration while units exist unless the user explicitly clears generated units first; the check runs in `ApplyQuickStructure` before `destroy_all`, since `restrict_with_error` alone does not surface a failure under `destroy_all` (see decision 5a).
- [Risk] Gating the "structure exists" check on `level_2 > 0` alone (decision 9a) instead of requiring `level_1 > 0` too could, in principle, mask a property that has zero sections of any kind. → Mitigation: `level_2 == 0` already correctly means "no leaf sections at all" in that case, so the gate still behaves correctly — it only changes behavior for the specific case where `level_1 == 0` but `level_2 > 0` (single-level formats, `skip_top_level`), which is exactly the case being fixed.

## Migration Plan

- No schema changes. No backfill needed — `ApplyAutomaticUnits` is only invoked from the still-in-progress wizard flow (draft properties); no persisted "wrong" state needs correcting beyond what already exists in draft properties currently stuck in step 3 (which we do not attempt to auto-repair).
- Roll out as a normal code deploy behind existing tests. Rollback is a plain revert since no data migration is involved.

## Open Questions

- None. Property types map deterministically to `units_in` via the existing `StructureFormatCatalog`; the three `identifier_format` values are documented in the `property-setup-wizard` spec; and the exact `block_sequential`/`sequential` formulas and the `units_per_leaf` naming were resolved during exploration (decisions 3, 7, 8 above).
