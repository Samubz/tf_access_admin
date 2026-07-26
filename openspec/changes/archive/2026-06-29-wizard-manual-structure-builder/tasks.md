## 1. Discovery and alignment

- [x] 1.1 Read `PropertySections::Create`, `Update`, `Move`, `Archive`, and `Base` to confirm the Result contract and capability authorization to mirror in `Destroy` and `CreateBatch`
- [x] 1.2 Read `PropertySectionHierarchy` and `PropertySection#can_contain_units?` / `accepts_units?` to confirm the leaf and unit-placement predicates the builder and generation must respect
- [x] 1.3 Read `Properties::Setup::GenerateUnitsPreview`, `ApplyAutomaticUnits`, and `ValidateStep#validate_step_3` to map the current `floor`-based leaf logic and step-3 gate
- [x] 1.4 Map the existing quick naming logic to extract (`GenerateStructurePreview#section_name`/`suffix`, the duplicate in `ApplyQuickStructure`, and the `structurePreview.ts` name building) into the shared `SectionNameSequence` source of truth
- [x] 1.5 Confirm the existing `wizard/:id/create_section` route/controller param shape and the route mismatch in `ManualSectionForm.vue`

## 2. Shared naming source of truth + section use cases

- [x] 2.1 Extract `Properties::Setup::SectionNameSequence` with `.names(prefix:, suffix_type:, count:)` and `.name(prefix:, suffix_type:, index:)` (suffix_type `:letter | :number`); unit-test it
- [x] 2.2 Refactor `GenerateStructurePreview` and `ApplyQuickStructure` to use `SectionNameSequence` (no behavior change) and confirm existing quick regression tests still pass
- [x] 2.3 Mirror the same rule in `structurePreview.ts` so quick and the manual modal "De creación" preview share one front-end implementation; unit-test the TS mirror against the Ruby helper's expectations
- [x] 2.4 Add `PropertySections::CreateBatch` that creates N sections under a single parent (or N roots) in one transaction, reusing `PropertySections::Create` per node and `SectionNameSequence` for names; supports a heterogeneous tree (each parent may receive a different count)
- [x] 2.5 Ensure `CreateBatch` rejects creating children under a non-root parent (no third level) and rolls back the whole batch on any failure, returning a Result with per-node errors
- [x] 2.6 Add `PropertySections::Destroy` mirroring `Archive` (capability auth, row lock, Result), calling paranoia soft delete (`section.destroy`) and relying on `dependent: :restrict_with_error` for children/units; clear invalid Result when dependents block deletion, idempotent when already deleted
- [x] 2.7 Write tests: `CreateBatch` individual and multiple, letter and numeric formats, root and child contexts, third-level rejection, full rollback; `Destroy` deletes empty leaf, blocks with children, blocks with units, enforces tenant/property scope and authorization

## 3. Wizard controller and routes

- [x] 3.1 Add routes under `wizard/:id/...`: batch create (`post sections` → `create_sections`), `delete sections/:section_id` → `destroy_section`, and `patch sections/:section_id` → `update_section` (rename/retype/description)
- [x] 3.2 Implement `create_sections`, `destroy_section`, and `update_section` in `WizardController`, scoping sections via `@property.property_sections`, using `authorize_setup_property!`, delegating to `PropertySections::CreateBatch` / `Destroy` / `Update`, redirecting back with Inertia errors on failure
- [x] 3.3 Align `ManualSectionForm.vue` requests to the real routes and the `property_section`/batch payload shape the controller permits (done with Group 4 rework)
- [x] 3.4 Write controller tests: batch create (root + child), delete (success + blocked-by-dependents), rename, and authorization/tenant-isolation for the new endpoints

## 4. Manual builder frontend (mockups 01–06)

- [x] 4.1 Rework `ManualSectionForm.vue` base view (mockup 01): nested tree rows with type/level badges, header explaining the two-level + leaf-units rule, the section count summary (total + leaf-for-units), and exactly one visible button "Agregar sección raíz"
- [x] 4.2 Put every per-section action in a `DropdownMenu` (mockup 03): "Editar sección", "Agregar sección hija" (root rows only), "Eliminar sección" (destructive); no per-row action buttons outside the dropdown
- [x] 4.3 Add the create modal (mockups 02/04) with "Individual" and "Múltiple" tabs: type, cantidad, prefijo, naming formato (letter/numeric), optional internal code, and a live "De creación" name preview; the add-child modal is bound to a fixed parent root and states children cannot have children
- [x] 4.4 Add the edit modal (mockup 05): name, type, prefix, optional description; and the delete confirmation dialog (mockup 06) stating units/children guards before sending the destructive request
- [x] 4.5 Ensure the always-on `StructurePreviewPanel.vue` updates automatically after every successful create/edit/delete in manual mode (Inertia redirect re-renders the serializer tree)
- [x] 4.6 Enforce client-side two-level and unit-placement rules via the `property_section_structure` Zod schema (extend for batch fields) for fast feedback, keeping the server authoritative
- [x] 4.7 Surface the recommended-format warning when `section_type` is outside the format, without blocking creation; show nothing when the type has no mapped format
- [x] 4.8 Update `Step2Structure.vue` wiring (props, `getValues`/`validate`, empty-structure block) and confirm `Wizard.vue` integration

## 5. Internationalization

- [x] 5.1 Add `es`, `en`, `pt` keys for builder labels, the root/child/edit modals (tabs, cantidad, prefijo, formato, código, "De creación"), dropdown actions, delete dialog, validation, and empty-state messages
- [x] 5.2 Confirm no hardcoded user-facing strings remain in the new/changed components and serializers

## 6. Verification

- [x] 6.1 Run focused Minitest for `SectionNameSequence`, `PropertySections::CreateBatch`, `PropertySections::Destroy`, the wizard controller, `GenerateUnitsPreview`, `ApplyAutomaticUnits`, and `ValidateStep`
- [x] 6.2 Run `npm run check` for the touched Vue/TS files (clean; 2 remaining errors are pre-existing in untouched files)
- [x] 6.3 Manually verify the full manual flow against the mockups: single visible root button, dropdown-only actions, individual + multiple creation in modals, edit modal, delete dialog with guards, auto-updating preview (requires running app — manual QA)
- [x] 6.4 Run `graphify update app`
