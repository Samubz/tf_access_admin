## 1. Lifecycle And Status Contract

- [x] 1.1 Inspect existing `ResidentialProperty` status validation, lifecycle services, catalog badges, serializers, and tests.
- [x] 1.2 Add `created` as a supported property status without changing ordinary non-wizard creation defaults.
- [x] 1.3 Update setup lifecycle services so new setup starts as `draft`, can finish as `created`, and can confirm as `configured`.
- [x] 1.4 Ensure `created` properties appear in property catalog/status displays with an explicit editable setup badge.
- [x] 1.5 Add model/service tests for valid `created` status, `draft -> created`, `draft -> configured`, `created -> configured`, `configured -> active`, `active -> archived`, and rejected backward transitions.

## 2. Wizard Editability Rules

- [x] 2.1 Inspect current setup wizard routes/controllers/serializers to identify how an existing property is loaded and how available steps/modes are computed.
- [x] 2.2 Allow authorized users to reopen `created`, `configured`, and `active` properties at step 1 with editable property data, property type, building format, manual sections, and manual units.
- [x] 2.3 Treat property identity fields as `address_line`, `city`, `country`, `name`, `property_type`, `region`, and `timezone`.
- [x] 2.4 Derive `normalized_name` from `name`, and derive property `code` from property type abbreviation plus `normalized_name` using the existing implemented convention.
- [x] 2.5 Treat building format as derived from `property_type` (via `StructureFormatResolver`, from `2026-06-29-improve-property-structure-wizard-formats`), not as an independently stored field.
- [x] 2.6 Block wizard editing for `inactive` and `archived` properties.
- [x] 2.7 Enforce status editability rules server-side, independent of frontend disabled controls.
- [x] 2.8 Add controller/policy tests for created/configured/active editable fields, inactive/archived rejection, name/type-driven normalized name/code regeneration, and rejected code collisions with client-facing name-change errors.

## 3. Destructive Structure Reset

- [x] 3.1 Implement a tenant-scoped, property-scoped setup reset service for structure-affecting changes.
- [x] 3.2 Detect property type and structure mode changes that require reset when sections or units already exist (building format is not a separate trigger; see 2.5).
- [x] 3.3 Require an explicit confirmation flag before applying a destructive reset.
- [x] 3.4 For `draft` properties, really destroy existing sections and units for the current property in an all-or-nothing transaction before persisting the new type or structure choice.
- [x] 3.5 For `created`, `configured`, and `active` properties, remove existing sections and their associated units in an all-or-nothing transaction before persisting the new type or structure choice, using the operational-history-aware soft-delete/archive rule from section 7.
- [x] 3.6 Preserve existing structure and property type/structure mode when the confirmation is cancelled or missing.
- [x] 3.7 Add tests for draft hard reset, existing-property reset (soft-delete branch and archive branch), cancelled reset, missing confirmation, tenant isolation, and rollback on failure.

## 4. Frontend Wizard UX

- [x] 4.1 Update wizard props/types to expose property setup status, editability, available modes, and whether a structure-affecting change requires confirmation.
- [x] 4.2 Add confirmation dialog copy for destructive structure reset in `es`, `en`, and `pt`.
- [x] 4.3 Show the reset confirmation before submitting property type, building format, or structure mode changes that would delete existing structure.
- [x] 4.4 Hide quick automatic structure and automatic unit generation for `created`, `configured`, and `active` edit sessions.
- [x] 4.5 Keep property identity/type/building format controls editable for `created`, `configured`, and `active` properties while showing the reset confirmation when required.
- [x] 4.6 Add or update frontend validation/types so created/configured/active mode availability is reflected consistently.
- [x] 4.7 Show client-facing validation errors when a name/type edit would generate a colliding property code (already covered by existing generic field-error display machinery; verified via the backend collision test).

## 5. Step 5 Outcomes

- [x] 5.1 Update step 5 backend actions to support saving as `created` and confirming as `configured`.
- [x] 5.2 Update step 5 UI to present the two outcomes with clear consequences and required acknowledgement for configured confirmation, shown only when status is `draft` or `created`.
- [x] 5.3 For `configured` and `active` edit sessions, show a single save control that preserves the current status and does not show the configured-confirmation control.
- [x] 5.4 Ensure completion view shows next actions appropriate to `created` vs `configured` (added a `reopen_setup` next action/card, shown for created/configured/active).
- [x] 5.5 Add tests for created completion, configured confirmation, created edits saved without confirmation remaining created, configured/active edits remaining configured/active with no configured-confirmation control shown, rejected active-to-configured attempts, failure preserving prior state, and completion next actions.

## 6. Archived Sections/Units Hidden From The Wizard

- [x] 6.1 Add a wizard-scoped `effective_status`-aware filter (self or nearest archived ancestor section) for structure trees, unit lists, and nested unit previews, without changing non-wizard section/unit administration views. (Structure-tree and counts/summary paths covered; a known minor gap — an individually archived unit still appearing in the nested tree preview under a non-archived section, in `Step2Structure`/`Step3Units` — is tracked separately since it doesn't affect counts/summary correctness.)
- [x] 6.2 Extend `Properties::Setup::BuildPreview` to exclude archived sections/units (in addition to the existing soft-deleted exclusion) from `counts` and the nested unit preview.
- [x] 6.3 Add tests proving an archived section (and units under it) and a directly archived unit under a non-archived section are excluded from wizard structure/unit views and from step 4/5 summary and confirmation counts.

## 7. Operational-History-Aware Section/Unit Removal

- [x] 7.1 Add a check for whether a unit has any `unit_ownerships`, `lease_contracts`, `unit_occupancies`, or `visits` records.
- [x] 7.2 Add a check for whether a section has operational history via its own units (a section with child sections cannot be removed as a single unit anyway — `dependent: :restrict_with_error` on `:children` blocks it until children are removed individually, so there is nothing to check transitively).
- [x] 7.3 When removing a section or unit through the wizard (manual delete or structure reset) and no operational history exists, soft-delete directly via the existing `Units::SoftDelete`/section soft-delete path, without an additional confirmation.
- [x] 7.4 When operational history exists, require an explicit user confirmation and archive via the existing `PropertySections::Archive`/`Units::Archive` instead of soft-deleting; do not modify `Units::Reactivate` or add any cascade of a literal `status = archived` write beyond what `PropertySections::Archive` already persists.
- [x] 7.5 Apply the same rule uniformly across manual single-section/unit delete and structure reset for `created`, `configured`, and `active` properties.
- [x] 7.6 Add tests for: no-history soft-delete (section and unit), with-history archive-with-confirmation (section and unit), blocked removal of a section with children, and that `Units::Reactivate` remains unmodified (still requires no code change, so its own pre-existing coverage still applies unaffected).

## 8. Manual Section Move In The Wizard

- [x] 8.1 Add a wizard-native controller action that invokes the existing `PropertySections::Move` service, for draft/created/configured/active contexts.
- [x] 8.2 Add wizard step 2 UI to move a section to a different parent (or to root): a "Move" action on `ManualSectionTreeRow.vue`, wired to a new dialog in `ManualSectionForm.vue` (a fresh, wizard-native dialog rather than reusing the retiring page's `SectionMoveDialog.vue`, since that component is tightly coupled to the old page's composables).
- [x] 8.3 Add tests for moving a section under a different root, moving a subsection to root, and rejected moves that violate hierarchy rules (moving a root under a subsection).

## 9. Step 3 "Manage Unit" Link

- [x] 9.1 Add a "manage unit" action to each unit row's action menu in wizard step 3 (`UnitTreeRow.vue`, threaded `propertyId` through `UnitSectionTreeRow.vue`/`ManualUnitsForm.vue`).
- [x] 9.2 Wire the action to navigate to the existing unit detail page (`/admin/residential_properties/:residential_property_id/units/:unit_id`).
- [x] 9.3 Verified the route matches the real Rails route (`bin/rails routes` — `admin_residential_property_unit GET /admin/residential_properties/:residential_property_id/units/:id`); no component-test harness exists for this frontend tree yet, consistent with the rest of this codebase's Vue components.

## 10. Retire The Standalone Structure Page

- [x] 10.1 Remove `Admin::ResidentialProperties::StructuresController`, its route, and `admin/residential_properties/structure.vue`.
- [x] 10.2 Remove components/composables used exclusively by that page: `SectionTree.vue`, `SectionMoveDialog.vue`, `usePropertySectionTree.ts`, `usePropertySectionSubmit.ts`. Investigation found `StructureForm.vue` was, contrary to the original design note, *not* actually shared with the wizard (no import existed in `Step2Structure.vue`/`Step3Units.vue`) — it was only reachable through the deleted page, so it was removed too, along with its own exclusive sub-components `SectionTreeNode.vue`, `SectionTreeUnit.vue`, and `SectionStatusBadge.vue`, and the now-orphaned `lib/breadcrumbs/property_structure.ts`. `BulkUnitsImportDrawer.vue` is genuinely shared (confirmed via `useBulkUnitsImportDrawer.ts`) and was kept.
- [x] 10.3 Remove `Admin::ResidentialProperties::PropertySectionsController` (create/update/move/archive) and its route; keep `PropertySections::Create`, `PropertySections::Update`, `PropertySections::Move`, and `PropertySections::Archive`, now invoked from the wizard-native actions added in sections 7 and 8.
- [x] 10.4 Remove `Admin::ResidentialProperties::UnitsController`'s now-orphaned `create`, `move`, and `archive` actions and routes (their only caller was the removed structure page); keep `index`, `show`, `update`, and `restore` (the unit detail page depends on them). Also fixed the now-dangling `structure_path` redirects in `set_unit`/`set_restorable_unit` (→ `admin_residential_properties_path`) and in the sibling `unit_ownerships_controller.rb`/`unit_occupancies_controller.rb` not-found rescues.
- [x] 10.5 Update `Admin::PropertySectionsController#edit` to redirect into the setup wizard instead of the removed structure page.
- [x] 10.6 Do not remove `PropertySections::TreeBuilder` (shared with `Properties::Setup::BuildPreview`).
- [x] 10.7 Add/update tests: added `test/controllers/admin/property_sections_controller_test.rb` (edit redirects into the wizard); trimmed `units_mutations_controller_test.rb` to drop create/move/archive coverage while keeping update/restore/index; updated `residential_properties/index.vue`, `property_sections/index.vue`, `PersonOccupanciesTab.vue`/`PersonOwnershipsTab.vue`, and `lib/breadcrumbs/unit.ts` links that pointed at the removed route (caught by the frontend type check, since the generated route helper disappeared).

## 11. Validation

- [x] 11.1 Run targeted Rails tests for residential property lifecycle and setup wizard edit/reset behavior. (337 assertions across lifecycle/reset/serializer/controller tests, 0 failures.)
- [x] 11.2 Run targeted controller/service tests for manual section and manual unit mutations, archive-vs-soft-delete, section move, and the retired structure page in created/configured/active contexts. (194 additional service-level tests across properties/setup, property_sections, units — 0 failures.)
- [x] 11.3 Run frontend type check if Vue/TypeScript props changed. (Clean; only 2 pre-existing, unrelated errors remain.)
- [x] 11.4 Run `openspec validate enable-wizard-editing-created-state --strict`. (Valid.)
- [x] 11.5 Run `graphify update app` after implementation changes. (3368 nodes, 5159 edges, 399 communities.)

## 12. Retire The Standalone Property Edit Page

- [x] 12.1 Confirm the edit page (`Admin::ResidentialPropertiesController#edit`/`#update`, `Properties::Update`) only covers identity fields already handled by the wizard for draft/created/configured/active, and that it never actually exposed a status selector in `edit.vue` despite the controller permitting `:status`.
- [x] 12.2 Remove `#edit`/`#update` actions and their routes; remove `Properties::Update` (unused elsewhere) and `admin/residential_properties/edit.vue`.
- [x] 12.3 Update entry points that linked to the removed page: `residential_properties/index.vue`'s "Editar" row action (removed — the existing "Configuración" wizard action already covers the editable statuses), `PersonOccupanciesTab.vue`/`PersonOwnershipsTab.vue`'s property-name links (now point to the wizard).
- [x] 12.4 Accept the `inactive`-property gap explicitly (see design.md Decision 12 and proposal Non-goals) rather than extend wizard editability to `inactive` in this change.
- [x] 12.5 Update/trim `test/controllers/admin/residential_properties_controller_test.rb` (drop edit/update coverage, adapt the cross-org test to exercise `archive` instead); run frontend type check (clean) and targeted Rails tests (7/7 pass).
