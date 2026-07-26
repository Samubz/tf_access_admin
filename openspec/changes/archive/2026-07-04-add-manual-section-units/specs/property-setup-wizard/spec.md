## ADDED Requirements

### Requirement: Step 3 supports manual section-level unit management

Step 3 SHALL provide a new `manual` unit management mode for draft properties. The mode SHALL use the same visual tree pattern already used by `ManualSectionForm` and `ManualSectionTreeRow`, with units rendered under their assigned section when present.

The manual mode requires at least one eligible section to exist; eligible section rows SHALL expose only an add-unit action, and ineligible section rows SHALL NOT show the add-unit action. Unit creation, edit, and deletion SHALL remain scoped to the current draft property and organization and require the property-scoped `manage_units` permission.

#### Scenario: Manual unit view reuses section preview

- **GIVEN** a draft property has persisted sections from step 2
- **WHEN** the user opens step 3 manual unit management
- **THEN** the step renders the same visual tree pattern used by `ManualSectionForm` and `ManualSectionTreeRow`
- **AND** any existing non-deleted units are shown beneath their assigned section

#### Scenario: Section rows expose only add-unit action

- **GIVEN** the user is viewing sections in step 3 manual unit management
- **WHEN** an eligible section row renders
- **THEN** it exposes an add-unit action
- **AND** it does not expose edit-section, add-child-section, or delete-section actions

#### Scenario: Ineligible section rows do not expose add-unit

- **GIVEN** a section cannot contain units according to the property-section contract
- **WHEN** the section row renders in manual unit mode
- **THEN** no add-unit action is shown for that section
- **AND** the user is not invited to submit a unit for that section

#### Scenario: Add-unit opens individual and multiple options

- **GIVEN** the user triggers add-unit from an eligible section
- **WHEN** the creation dialog opens
- **THEN** it offers individual and multiple creation modes
- **AND** created units are assigned to that section through the draft property's server-side context

#### Scenario: Ineligible section cannot receive units

- **GIVEN** a request references a section that is not eligible to contain units according to the property-section contract
- **WHEN** the server processes the unit creation
- **THEN** the mutation is rejected
- **AND** no unit is created or silently assigned elsewhere

#### Scenario: Manual unit mutations refresh preview

- **GIVEN** the user creates, edits, or deletes a unit in step 3
- **WHEN** the mutation succeeds
- **THEN** the response is used to refresh the persisted unit data shown in the preview
- **AND** the preview reflects the persisted non-deleted units without losing wizard state

#### Scenario: Automatic is default for new quick setup

- **GIVEN** a draft property reaches step 3 for the first time
- **AND** step 2 used quick structure
- **WHEN** no units mode has been persisted yet
- **THEN** the wizard selects automatic mode by default

#### Scenario: Manual is default when editing or resuming units

- **GIVEN** a draft property returns to step 3 after units have already been created or the units step has already been persisted
- **WHEN** the wizard renders the units step
- **THEN** manual mode is selected by default
- **AND** the user can switch to automatic or import when those modes are available

#### Scenario: Cross-organization unit mutation is denied

- **GIVEN** the user is operating in organization O
- **WHEN** a step 3 unit mutation references a property, section, or unit from organization Q
- **THEN** access is denied
- **AND** no foreign data is returned or mutated

#### Scenario: User without manage_units is denied

- **GIVEN** a user is authorized to run setup for draft property P
- **AND** the user lacks `manage_units` for P
- **WHEN** they attempt to create, edit, or soft-delete a unit through the setup wizard
- **THEN** authorization is denied
- **AND** no unit is created, edited, or deleted
