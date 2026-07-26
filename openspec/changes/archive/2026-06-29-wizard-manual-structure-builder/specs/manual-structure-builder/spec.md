## ADDED Requirements

### Requirement: Manual builder composes a free-form two-level section tree

The manual structure builder SHALL let an authorized user compose the property's section hierarchy freely, subject to the existing two-level limit: a section is either a root section (no parent) or a child of a root section. The builder MUST NOT allow creating a third level (a child of a child).

All section reads and writes SHALL be scoped to the draft property and its organization. Section creation SHALL be authorized through the property-setup capability (`authorize_setup_property!`) and delegated to `PropertySections::Create`; the builder MUST NOT bypass model validations or the `PropertySectionHierarchy` rules.

#### Scenario: User adds a root section

- **GIVEN** an authorized user editing a draft property in manual mode
- **WHEN** they submit a section with no parent
- **THEN** the section is persisted as a root section via `PropertySections::Create`
- **AND** it appears in the live structure preview under the property

#### Scenario: User adds a child section under a root

- **GIVEN** a persisted root section
- **WHEN** the user submits a new section selecting that root as parent
- **THEN** the section is persisted as a child of that root
- **AND** the preview nests it under its parent

#### Scenario: Third level is rejected

- **GIVEN** a root section with a child section
- **WHEN** the user attempts to add a section whose parent is the child section
- **THEN** the operation is rejected with the existing two-level validation message
- **AND** no section is created

#### Scenario: Builder stays scoped to the property and organization

- **WHEN** the builder loads parent options and the current tree
- **THEN** only sections belonging to the current draft property and organization are shown
- **AND** sections from other properties or organizations are never selectable or returned

### Requirement: Units may attach only to leaf sections

The builder SHALL reflect the rule that units attach only to sections that accept units: a root section with no children, or a child section. A section that has children SHALL NOT be presented or treated as a unit container, consistent with `PropertySection#can_contain_units?` (`eligible_for_units? && accepts_units?`).

#### Scenario: Childless root is a valid unit container

- **GIVEN** a root section with no children
- **WHEN** the structure is evaluated for unit placement
- **THEN** that root section is treated as a leaf eligible to hold units

#### Scenario: Root with children is not a unit container

- **GIVEN** a root section that has at least one child section
- **WHEN** the structure is evaluated for unit placement
- **THEN** that root section is excluded from unit-eligible leaves
- **AND** only its child sections (if unit-eligible) are offered as containers

#### Scenario: Adding a child to a section that holds units is rejected

- **GIVEN** a root section that already holds units
- **WHEN** the user attempts to add a child section under it
- **THEN** the operation is rejected with the existing `parent_has_units` validation
- **AND** the section tree is unchanged

### Requirement: User can rename and delete sections during setup

The builder SHALL let the user delete a section, and SHALL surface the model-level guards rather than silently failing. Deleting a section that has children or units SHALL be governed by the existing `PropertySection` removal rules (`dependent: :restrict_with_error` / soft delete); the builder MUST present a clear confirmation and error feedback.

#### Scenario: User deletes an empty leaf section

- **GIVEN** a leaf section with no children and no units
- **WHEN** the user confirms deletion
- **THEN** the section is removed and disappears from the live preview
- **AND** the deletion is scoped and authorized like other wizard mutations

#### Scenario: Deleting a section with dependents is blocked

- **GIVEN** a section that has child sections or units
- **WHEN** the user attempts to delete it
- **THEN** the deletion is rejected with a clear message explaining the dependents
- **AND** the structure remains intact

#### Scenario: Delete requires explicit confirmation

- **GIVEN** the user clicks delete on a section
- **WHEN** the confirmation has not yet been given
- **THEN** no destructive request is sent until the user confirms

### Requirement: Builder reflects structure live in the shared preview panel

The builder SHALL render the current persisted tree in the shared structure preview panel used across step 2 and step 3, updating after each successful create or delete. The panel MUST render sections only in step 2 and handle the absence of units without error.

#### Scenario: Preview updates after each mutation

- **GIVEN** the user adds or deletes a section
- **WHEN** the mutation succeeds
- **THEN** the shared preview panel reflects the new tree without a full page reload of wizard state being lost

#### Scenario: Empty manual structure shows an empty state

- **GIVEN** manual mode is selected and no section exists
- **WHEN** step 2 renders
- **THEN** the preview shows an empty-state message
- **AND** continuation is blocked until at least one section exists

### Requirement: Builder shows recommended-format guidance without enforcing it

When the `property_type` has a mapped `PropertyStructureFormat`, the builder SHALL warn when a chosen `section_type` is outside the recommended types, but MUST NOT block free-form creation. When no format is mapped, no warning is shown.

#### Scenario: Off-format section type warns but is allowed

- **GIVEN** a property type with a recommended format
- **WHEN** the user selects a `section_type` not in the recommended set
- **THEN** an inline warning lists the recommended types
- **AND** the user may still create the section

#### Scenario: Unmapped property type shows no format warning

- **GIVEN** a property type with no mapped format
- **WHEN** the user creates sections of any eligible type
- **THEN** no format warning is shown

### Requirement: Builder layout and actions follow the reference mockups

The manual builder UI SHALL live in `ManualSectionForm.vue` and follow the functional and informational layout implied by:

* `mockups/wizard-manual-structure-builder/01-property-setup-structure-manual-builder.png`
* `mockups/wizard-manual-structure-builder/02-property-setup-structure-add-root-sections-modal.png`
* `mockups/wizard-manual-structure-builder/03-property-setup-structure-section-actions-dropdown.png`
* `mockups/wizard-manual-structure-builder/04-property-setup-structure-add-child-sections-modal.png`
* `mockups/wizard-manual-structure-builder/05-property-setup-structure-edit-section-modal.png`
* `mockups/wizard-manual-structure-builder/06-property-setup-structure-delete-section-dialog.png`

The contract covers action placement, modal-based creation/editing, dialog-based deletion, and the live preview. It does NOT require reproducing exact colors, spacing, or component styling beyond what is needed to satisfy the observable behavior.

The base view (mockup 01) SHALL expose exactly one visible creation button, "Agregar sección raíz". All per-section actions — edit, add child section, and delete — SHALL live exclusively inside each section's `DropdownMenu`; the builder MUST NOT render per-row action buttons outside that dropdown. "Agregar sección hija" SHALL exist only within the dropdown of a root section.

#### Scenario: Base view exposes a single visible creation button

- **GIVEN** the manual builder is shown in step 2
- **WHEN** the structure list renders
- **THEN** the only visible creation button is "Agregar sección raíz"
- **AND** the header explains the two-level limit and that units attach to leaf sections only
- **AND** a per-section "⋯" dropdown trigger is shown on each row

#### Scenario: All per-section actions live in the dropdown

- **GIVEN** a section row in the builder
- **WHEN** the user opens its "⋯" dropdown
- **THEN** the dropdown offers "Editar sección", "Agregar sección hija", and "Eliminar sección"
- **AND** no edit, add-child, or delete control is rendered as a visible per-row button outside the dropdown

#### Scenario: Add-child action is only available on root sections

- **GIVEN** a child section (a section whose parent is a root)
- **WHEN** the user opens its dropdown
- **THEN** "Agregar sección hija" is not offered, because a third level is not allowed
- **AND** the action appears only in the dropdown of root sections

#### Scenario: Create and edit happen in modals, delete in a confirm dialog

- **WHEN** the user triggers "Agregar sección raíz", "Agregar sección hija", or "Editar sección"
- **THEN** the corresponding form opens in a modal (mockups 02, 04, 05)
- **AND** triggering "Eliminar sección" opens a confirmation dialog (mockup 06) before any destructive request is sent

#### Scenario: Delete dialog states the dependent guards

- **GIVEN** the delete confirmation dialog for a section
- **WHEN** it renders
- **THEN** it names the section being removed
- **AND** it states that a section containing units cannot be deleted and that child sections must be removed first, consistent with the model removal rules

### Requirement: Section creation supports individual and multiple modes

The creation modal SHALL offer two modes, "Individual" and "Múltiple". Individual creates a single section; Múltiple generates a batch under one parent context from a `cantidad`, an optional `prefijo`, and a naming `formato` (letter `A, B, C…` or numeric `1, 2, 3…`), with an optional internal code/prefix. The modal SHALL show a live "De creación" preview of the names that will be generated.

The add-root modal creates root sections; the add-child modal is bound to a fixed parent root section and SHALL create only child sections under it. Batch creation MUST respect the two-level limit and unit-placement rules and SHALL persist through the existing section creation path; child batches MUST NOT create a third level.

#### Scenario: Multiple mode generates a named batch

- **GIVEN** the add-root modal in "Múltiple" mode
- **WHEN** the user sets a type, a cantidad, a prefijo, and a letter or numeric naming format
- **THEN** the "De creación" preview lists the resulting names (e.g., "Torre A, Torre B")
- **AND** confirming creates the batch of root sections and the live preview updates

#### Scenario: Child modal is scoped to its parent root

- **GIVEN** the user chose "Agregar sección hija" on a root section
- **WHEN** the add-child modal opens
- **THEN** it shows the fixed parent ("Sección padre: Torre A") and the sections are created under that root
- **AND** the modal communicates that child sections cannot themselves have children

#### Scenario: Individual mode creates a single section

- **GIVEN** the creation modal in "Individual" mode
- **WHEN** the user provides a name and type and confirms
- **THEN** exactly one section is created in the corresponding context (root or under the fixed parent)

### Requirement: Structure preview updates automatically after each change

The structure preview panel SHALL update automatically after every successful create, edit, or delete in the manual builder, without requiring a manual refresh action. The preview reflects the persisted tree and the auxiliary note SHALL indicate that it updates automatically.

#### Scenario: Preview reflects a creation immediately

- **GIVEN** the user creates one or more sections via a modal
- **WHEN** the creation succeeds
- **THEN** the preview panel shows the new sections in their correct hierarchy without a manual refresh

#### Scenario: Preview reflects edits and deletions immediately

- **GIVEN** the user renames or deletes a section
- **WHEN** the operation succeeds
- **THEN** the preview panel updates to reflect the new name or the removal automatically
