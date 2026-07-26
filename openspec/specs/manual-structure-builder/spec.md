# manual-structure-builder

## Purpose

Defines the manual structure builder in property setup wizard step 2: free-form two-level section trees, batch creation, rename/delete during draft, live preview integration, and mockup-aligned UI behavior.

## Requirements

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

The creation modal SHALL offer two modes, "Individual" and "Múltiple". Individual creates a single section; Múltiple generates a batch under one parent context from a `cantidad`, an optional `prefijo`, and a naming `formato` (letter `A, B, C…` or numeric `1, 2, 3…`). Section codes are assigned automatically by the backend; the modal MUST NOT expose a code input. The modal SHALL show a live "De creación" preview of the names that will be generated.

Batch name allocation SHALL be sibling-collision-aware: when generating `cantidad` names, the system SHALL skip any candidate whose full normalized name already matches an existing sibling in the same parent context, advancing the sequence until it has allocated `cantidad` free names. Allocation SHALL compare complete normalized candidates only (trim, whitespace-collapse, NFKC, downcase) and MUST NOT parse or infer suffixes from existing names. The suffix sequence is bounded (letters `A–Z`, numbers up to a fixed cap); when the range is exhausted before `cantidad` free names are found, the batch SHALL be rejected as invalid with an `insufficient_available_names` error rather than creating a partial batch. The live "De creación" preview SHALL mirror this same allocation (skipped names and the insufficiency condition) so the preview matches what will actually be persisted.

The add-root modal creates root sections; the add-child modal is bound to a fixed parent root section and SHALL create only child sections under it. Batch creation MUST respect the two-level limit and unit-placement rules and SHALL persist through the existing section creation path; child batches MUST NOT create a third level.

#### Scenario: Multiple mode generates a named batch

- **GIVEN** the add-root modal in "Múltiple" mode
- **WHEN** the user sets a type, a cantidad, a prefijo, and a letter or numeric naming format
- **THEN** the "De creación" preview lists the resulting names (e.g., "Torre A, Torre B")
- **AND** confirming creates the batch of root sections and the live preview updates
- **AND** each section receives a server-derived code

#### Scenario: Child modal is scoped to its parent root

- **GIVEN** the user chose "Agregar sección hija" on a root section
- **WHEN** the add-child modal opens
- **THEN** it shows the fixed parent ("Sección padre: Torre A") and the sections are created under that root
- **AND** the modal communicates that child sections cannot themselves have children

#### Scenario: Individual mode creates a single section

- **GIVEN** the creation modal in "Individual" mode
- **WHEN** the user provides a name and type and confirms
- **THEN** exactly one section is created in the corresponding context (root or under the fixed parent)
- **AND** the section receives a server-derived code

#### Scenario: No code input in creation or edit modal

- **WHEN** the user opens the add-section or edit-section modal
- **THEN** no `code` field is visible or submittable

#### Scenario: Multiple mode skips names already taken by siblings

- **GIVEN** a parent context that already contains a section named "Torre A"
- **WHEN** the user generates a "Múltiple" batch with prefijo "Torre", letter format, and cantidad 2
- **THEN** allocation skips "Torre A" and produces "Torre B" and "Torre C"
- **AND** the "De creación" preview shows the same names before the user confirms

#### Scenario: Batch is rejected when the suffix range is exhausted

- **GIVEN** a parent context whose existing siblings occupy the entire suffix range for the chosen format
- **WHEN** the user attempts to generate a batch that needs more free names than remain
- **THEN** the batch is rejected as invalid with an `insufficient_available_names` error
- **AND** no partial batch is created

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

### Requirement: Shared preview supports unit-management action mode

The shared structure preview SHALL support a unit-management action mode for step 3 using the existing `ManualSectionForm` / `ManualSectionTreeRow` visual pattern. In this mode, section nodes SHALL render the persisted hierarchy and unit counts/details, while section-level actions are restricted to adding units on eligible unit containers.

The mode MUST NOT change the step 2 manual builder contract: step 2 continues to expose section creation/edit/delete actions according to the manual-structure-builder requirements and renders sections only.

#### Scenario: Step 3 preview renders units under sections

- **GIVEN** a persisted structure with units assigned to leaf sections
- **WHEN** the preview renders in unit-management mode
- **THEN** each non-deleted unit appears under its assigned section
- **AND** deleted units are omitted
- **AND** each rendered unit includes the persisted ID needed for edit and delete actions

#### Scenario: Unit-management mode hides section editing actions

- **GIVEN** the preview renders in unit-management mode
- **WHEN** the user opens or inspects actions for a section row
- **THEN** only the add-unit action is available for eligible sections
- **AND** section edit, add-child, and delete actions are not available

#### Scenario: Ineligible sections have no unit action

- **GIVEN** the preview renders a section that cannot contain units
- **WHEN** the user inspects the section row
- **THEN** no add-unit action is shown
- **AND** no disabled or hidden-submit action is provided for that section

#### Scenario: Step 2 section builder behavior is unchanged

- **GIVEN** the user is in step 2 manual structure builder
- **WHEN** the shared preview and section rows render
- **THEN** units are not shown as actionable step 2 content
- **AND** section actions remain governed by the existing step 2 manual builder contract

#### Scenario: Preview handles sections without units

- **GIVEN** a section has no non-deleted units
- **WHEN** the preview renders in unit-management mode
- **THEN** the section remains visible
- **AND** the unit area shows an empty state or zero-unit indication without hiding the section

### Requirement: Unit rows expose edit and delete dropdown actions

Unit rows rendered inside the shared preview SHALL expose a dropdown menu with exactly edit and delete actions. Editing SHALL open a unit edit dialog. Deleting SHALL open a confirmation dialog before any destructive request is sent.

#### Scenario: Unit row dropdown has edit and delete

- **GIVEN** a unit row appears in the step 3 preview
- **WHEN** the user opens its dropdown menu
- **THEN** the menu offers edit and delete actions
- **AND** no section actions are shown for the unit row

#### Scenario: Edit action opens unit dialog

- **GIVEN** the user selects edit from a unit row dropdown
- **WHEN** the edit dialog opens
- **THEN** it is populated with the unit's editable descriptive fields
- **AND** it does not expose section, property, organization, status, lifecycle, or code fields

#### Scenario: Delete action requires confirmation

- **GIVEN** the user selects delete from a unit row dropdown
- **WHEN** the confirmation dialog has not been confirmed
- **THEN** no delete request is sent
- **AND** the unit remains visible

### Requirement: Manual builder supports editable setup statuses

The manual structure builder SHALL operate in draft, created, configured, and active setup contexts. For created, configured, and active properties, the wizard SHALL expose manual section management and SHALL NOT offer quick automatic structure generation.

Manual section creation, edit, and deletion SHALL remain scoped to the current organization and current property, and SHALL continue delegating to the existing section services and hierarchy rules.

Manual section deletion is independent from destructive structure reset. When a user manually deletes one section, the system SHALL check whether the section or any of its associated units has operational history (`unit_ownerships`, `lease_contracts`, `unit_occupancies`, or `visits`). If none has operational history, the system SHALL soft-delete that section and its associated units directly, without requiring an additional confirmation beyond the ordinary delete action, and without deleting unrelated sections or units. If the section or any of its associated units has operational history, the system SHALL instead require an explicit user confirmation and archive the section (via the existing `PropertySections::Archive`) and its associated units (via the existing `Units::Archive`) rather than soft-deleting them; archiving does not cascade a literal `status = archived` write to descendants beyond what `PropertySections::Archive` already does, relying on computed effective status, and the archived section/units are excluded from the wizard per the `property-setup-wizard` capability. Neither path requires the destructive reset confirmation.

#### Scenario: Created property can edit manual structure

- **GIVEN** property P has status `created`
- **WHEN** an authorized setup user opens manual structure editing
- **THEN** they can create, rename, and delete sections according to manual builder rules
- **AND** all mutations remain scoped to P and its organization

#### Scenario: Configured property can edit manual structure

- **GIVEN** property P has status `configured`
- **WHEN** an authorized user opens manual section management from the wizard
- **THEN** they can use manual section actions allowed by their permissions
- **AND** quick automatic structure generation is not offered

#### Scenario: Active property can edit manual structure

- **GIVEN** property P has status `active`
- **WHEN** an authorized user opens manual section management from the wizard
- **THEN** they can use manual section actions allowed by their permissions
- **AND** quick automatic structure generation is not offered

#### Scenario: Manual section delete soft-deletes associated units without operational history

- **GIVEN** property P has status `created`, `configured`, or `active`
- **AND** section S has associated units, none of which has operational history
- **WHEN** an authorized setup user deletes section S through manual structure management
- **THEN** section S is soft-deleted
- **AND** units associated with section S are soft-deleted
- **AND** unrelated sections and units remain unchanged
- **AND** destructive reset confirmation is not required

#### Scenario: Manual section delete requires confirmation and archives when a unit has operational history

- **GIVEN** property P has status `created`, `configured`, or `active`
- **AND** section S has a unit with `unit_ownerships`, `lease_contracts`, `unit_occupancies`, or `visits` records
- **WHEN** an authorized setup user attempts to delete section S through manual structure management
- **THEN** the system requires an explicit confirmation before proceeding
- **AND** upon confirmation, section S and its associated units are archived rather than soft-deleted
- **AND** unrelated sections and units remain unchanged
- **AND** destructive reset confirmation is not required
- **AND** archiving does not write `status = archived` onto descendants beyond what `PropertySections::Archive` already persists

#### Scenario: Inactive archived properties cannot edit manual structure

- **GIVEN** property P has status `inactive` or `archived`
- **WHEN** a user attempts to mutate sections through the setup wizard
- **THEN** the mutation is rejected
- **AND** no section is created, edited, or deleted

### Requirement: Manual builder supports moving a section to a different parent

The wizard SHALL let an authorized setup user move an existing section to a different parent (or to root) using the existing `PropertySections::Move` service and its hierarchy rules, for draft, created, configured, and active setup contexts. This capability is native to the wizard's manual structure step; it is not offered through any page outside the setup wizard.

#### Scenario: Setup user moves a section under a different root

- **GIVEN** property P has root sections A and B, with subsection S under A
- **WHEN** an authorized setup user moves S to be a subsection of B through the wizard
- **THEN** S's parent becomes B
- **AND** the move is rejected if it would violate hierarchy depth, cycle, or sibling-uniqueness rules

#### Scenario: Setup user moves a subsection to root

- **GIVEN** property P has subsection S under root A
- **WHEN** an authorized setup user moves S to root through the wizard
- **THEN** S becomes a root section
