## Context

Wizard step 2 supports three modes (`none`, `manual`, `quick`). Quick mode is fully built (format catalog, backend preview, `ApplyQuickStructure`, confirm-before-advance). Manual mode is a stub: `ManualSectionForm.vue` only appends sections, displays a flat list, has no edit/delete, and POSTs to `/admin/property_setup/wizard/:id/sections` — a route that does not exist (the real route is `wizard/:id/create_section`). Automatic unit generation in step 3 was gated to `structure_mode === 'quick'` by the archived `improve-property-structure-wizard-formats` change, and `Properties::Setup::GenerateUnitsPreview` hardcodes `SectionTypes::FLOOR` as the leaf where units land.

Existing building blocks we will reuse:
- `PropertySection` with `acts_as_paranoid` (soft delete via `deleted_at`) and `dependent: :restrict_with_error` on `children` and `units`.
- `PropertySectionHierarchy` concern: the single source of truth for the two-level limit, parent coherence, cycle prevention, and the unit-placement rules (`parent_cannot_have_units`, `container_cannot_have_units`, `accepts_units? = children.none?`, `can_contain_units? = eligible_for_units? && accepts_units?`).
- `PropertySections::Create`, `Update`, `Move`, `Archive`, `TreeBuilder` use cases (Result-returning, capability-authorized).
- `Properties::Setup::*` wizard services and `StructurePreviewPanel.vue` shared between step 2 and step 3.

## Goals / Non-Goals

**Goals:**
- A real manual builder in step 2: create, rename, delete sections; pick type and parent; live preview via the shared panel.
- Enforce existing hierarchy and unit-placement rules through the domain services — never reimplement them in Vue or controllers.
- Make step-3 automatic generation work for manual structures by deriving unit-eligible leaf sections from the actual tree, preserving the established identifier-format rules.
- Full i18n (`es`, `en`, `pt`) for all new strings.

**Non-Goals:**
- No change to the two-level limit or `SectionTypes` eligibility.
- No reparenting UX beyond what `PropertySections::Move` already offers (drag-and-drop reorder is out of scope; parent is chosen via the form).
- No bulk/CSV structure import; no quick-mode or catalog changes.

## Decisions

### D1: Reuse existing `PropertySections::*` use cases; add only `Destroy`
The builder's create/rename map to `PropertySections::Create` / `Update`; parent changes to `Move`. For removal during draft setup we add `PropertySections::Destroy`, a thin Result-returning use case that authorizes via the setup/manage-sections capability and calls `section.destroy` (paranoia soft delete). Because `children` and `units` are `dependent: :restrict_with_error`, deleting a section with dependents fails cleanly and we surface the error — satisfying the "deletion blocked" scenarios without custom guard logic.
- *Why not `Archive`?* `Archive` only flips status to `archived` and intentionally keeps the node in the tree; during draft construction the user expects a mistaken section to disappear. Soft delete via paranoia removes it from default scope while preserving auditability, matching the project's soft-delete preference.
- *Alternative considered:* hard `delete` — rejected; loses audit trail and diverges from `acts_as_paranoid`.

### D2: Wizard controller endpoints for section mutations
Fix `create_section` wiring and add `destroy_section` (and, if rename/parent edits are exposed, `update_section`). New routes under the existing `wizard/:id/...` block:
- `post wizard/:id/create_section` (exists) — align `ManualSectionForm` to this route and the `property_section` param shape the controller already permits.
- `delete wizard/:id/sections/:section_id` → `wizard#destroy_section`.
- `patch wizard/:id/sections/:section_id` → `wizard#update_section` (rename / type / parent), delegating to `Update`/`Move`.
All endpoints reuse `authorize_setup_property!` and scope the section through `@property.property_sections` so tenant/property isolation is guaranteed. Mutations redirect back to the wizard (Inertia) so the serializer re-renders the live tree.

### D3: Step-3 gate unchanged — automatic generation remains quick-mode only
Automatic unit generation in step 3 is gated to `structure_mode === 'quick'`, as established by the archived `improve-property-structure-wizard-formats` change. Manual mode and none mode continue to offer only single creation and bulk import. `units_in` from the active `PropertyStructureFormat` drives leaf selection and identifier-format rules; it is not defined for manual trees.
- *Why:* manual structures are heterogeneous and have no format-derived `units_in`; the existing automatic-generation engine assumes a format-backed structure. Extending it to free-form trees is out of scope for this change.

### D4: Frontend — rework `ManualSectionForm.vue` into a builder, keep the shared preview
`ManualSectionForm.vue` becomes the builder and follows the reference mockups. The base view (mockup 01) exposes exactly one visible creation button, "Agregar sección raíz"; every per-section action — edit, add child, delete — lives only inside that row's `DropdownMenu` (mockup 03), with no per-row buttons outside the dropdown. "Agregar sección hija" appears only in the dropdown of root sections. Create and edit open in modals (mockups 02, 04, 05); delete opens a confirmation dialog (mockup 06). The always-on `StructurePreviewPanel.vue` remains the canonical live view and updates automatically after each successful mutation. Client-side Zod validation (`property_section_structure` schema) mirrors the two-level/leaf rules for fast feedback, but the server remains authoritative. Step 2 continues to expose `getValues`/`validate` to `Wizard.vue`.

### D5: Per-parent heterogeneous batch creation — distinct from the quick engine
The creation modals support "Individual" and "Múltiple" modes. Múltiple generates a batch under a single parent context from `cantidad`, optional `prefijo`, and a naming `formato` (letter `A,B,C…` or numeric `1,2,3…`), with an optional internal code. This is intentionally **not** the quick-structure engine: quick produces a symmetric tree (the same number of children per parent, driven by the format catalog and `units_in`), whereas manual lets each parent receive a **different** number of children, producing an asymmetric/heterogeneous tree with no catalog dependency.
- *Decision:* implement a dedicated per-parent batch helper in `PropertySections::*` (e.g. `PropertySections::CreateBatch`) that creates N sections under one parent (or N roots) in a single transaction, reusing `PropertySections::Create` per node so all `PropertySectionHierarchy` rules and the two-level limit still apply. The add-root modal targets the root context; the add-child modal is bound to a fixed parent root and never creates a third level.
- *Why not reuse `ApplyQuickStructure`?* It assumes a whole-property format with uniform fan-out; bending it to "one parent, one level, arbitrary count" would leak catalog/format assumptions into manual mode.
- *Trade-off:* a little extra code for a clean, catalog-free manual path that supports heterogeneous trees — which is what the feature requires.

### D6: Single source of truth for section naming (shared by quick and manual)
The naming rule "prefix + suffix, where suffix is a letter (`A,B,C…`) or a number (`1,2,3…`)" currently lives privately inside `GenerateStructurePreview` (`section_name`/`suffix`) and is duplicated in `ApplyQuickStructure`. We adopt **option C**: extract it into one shared value object — `Properties::Setup::SectionNameSequence` — and route every producer through it so quick and manual always agree.
- *API:* `SectionNameSequence.names(prefix:, suffix_type:, count:)` → ordered `["Torre A", "Torre B"]`, plus a single-index `.name(prefix:, suffix_type:, index:)`. `suffix_type` is the existing `:letter | :number`.
- *Backend call sites refactored to use it:* `GenerateStructurePreview` (quick preview), `ApplyQuickStructure` (quick commit), and `PropertySections::CreateBatch` (manual commit). No behavior change for quick — covered by existing `GenerateStructurePreview` / `ApplyQuickStructure` regression tests.
- *Frontend:* the manual modal's live "De creación" preview mirrors the same rule in the existing TS structure-preview util (`structurePreview.ts`), so the modal preview and the persisted result match without a per-keystroke network round-trip. The TS mirror and the Ruby helper are the only two places the rule exists, kept trivially in sync (letter/number + prefix), and both are unit-tested.
- *Why C over a backend-only helper:* the rule already exists in two backend services and will gain a third (manual); centralizing now removes the drift risk permanently instead of adding a fourth copy.

## Risks / Trade-offs

- [Soft-deleted sections could collide with unique indexes on re-create] → paranoia's unique indexes are already scoped `WHERE deleted_at IS NULL`, so a new section with the same name/parent is allowed after deletion; no extra handling needed.
- [Inertia redirect after each mutation could feel heavy] → mutations use `preserveScroll`/`preserveState` and the wizard already re-renders from the serializer; acceptable and consistent with current quick/manual flows.
- [Rename/parent edits widen surface] → if scope risk is high, ship create+delete first and treat `update_section` as optional; specs allow rename/delete but the minimal slice is create+delete+preview.

## Migration Plan

No schema migration. Pure additive behavior:
1. Add `PropertySections::Destroy` (+ tests).
2. Extract `Properties::Setup::SectionNameSequence` and route `GenerateStructurePreview` + `ApplyQuickStructure` through it (no behavior change); add `PropertySections::CreateBatch` (per-parent / per-root batch, single transaction) reusing `Create` per node and the same naming helper.
3. Add wizard routes/controller actions for batch create and destroy (and rename via update); fix `create_section` form target.
4. Rework `ManualSectionForm.vue` (modal create/edit, dropdown actions, delete dialog, auto preview) and wire `Step2Structure.vue` / `Wizard.vue`.
5. Add i18n keys to `es`, `en`, `pt`.
Rollback is removal of the new routes/actions; no data backfill involved.

## Open Questions

- Should manual mode also support reordering siblings (position) in this slice, or defer to a later change? (Default: defer; parent/type/name only.)
- Reparenting is out of the mockups (edit modal changes name/type/description, not parent). Default: `update_section` covers rename/retype/description only; defer `Move`-based reparenting.
