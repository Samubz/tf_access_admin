## ADDED Requirements

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
