# property-setup-wizard

## ADDED Requirements

### Requirement: Authorized users can start the property setup wizard

The system SHALL expose a guided property setup flow for creating a complete residential property configuration from scratch.

Only users with the organizational capability to manage properties in the current organization SHALL be able to start or confirm the wizard.

#### Scenario: Tenant admin starts wizard

- **GIVEN** an authenticated tenant administrator in organization O
- **WHEN** they open the new property setup entry point
- **THEN** the wizard loads at step 1
- **AND** the flow is scoped to organization O

#### Scenario: Unauthorized user is denied

- **GIVEN** an authenticated user without property-management capability in organization O
- **WHEN** they attempt to open or confirm the wizard
- **THEN** access is denied
- **AND** no draft setup state is created for them

#### Scenario: Cross-organization access is denied

- **GIVEN** a user operates in organization O
- **WHEN** they attempt to resume or confirm a setup draft belonging to organization Q
- **THEN** access is denied
- **AND** no records are created or updated in Q

### Requirement: Wizard presents a five-step guided layout

The wizard UI SHALL follow the observable layout contract derived from the reference mockups `create-property-step-1.png` through `create-property-step-5.png`.

The layout MUST include:

* a persistent page title and short description explaining that this is a guided setup flow;
* a horizontal stepper with exactly five steps labeled for property data, structure, units, summary and confirmation;
* a main content area for the active step;
* an auxiliary panel when the reference flow shows contextual preview or summary information;
* a footer action area with navigation controls.

The stepper MUST distinguish the current step, completed steps and pending steps.

#### Scenario: Step 1 shows property data layout

- **GIVEN** the user is on step 1
- **WHEN** the wizard renders
- **THEN** the stepper highlights "Datos de la propiedad" as the current step
- **AND** the main area shows the property data form
- **AND** an auxiliary "Resumen inicial" panel reflects the entered values as they become available

#### Scenario: Completed steps are marked in the stepper

- **GIVEN** the user has completed steps 1 and 2
- **WHEN** they view step 3
- **THEN** steps 1 and 2 appear as completed in the stepper
- **AND** step 3 appears as the current step
- **AND** steps 4 and 5 appear as pending

#### Scenario: Footer exposes primary and secondary actions per step

- **GIVEN** the user is on any wizard step except the first
- **WHEN** the footer renders
- **THEN** a secondary "Atrás" action is available to return to the previous step
- **AND** a secondary "Cancelar" action is available to exit the flow
- **AND** a primary forward action is available when the current step is valid

### Requirement: Step 1 captures basic property data

Step 1 SHALL collect the minimum property data needed to continue the guided setup.

Required fields (persisted on `ResidentialProperty`):

* property name;
* property type;
* address.

Wizard planning field (UX only, not persisted as a domain column):

* estimated unit count — used to populate the Step 1 summary panel and inform the user's planning; it is not stored on `ResidentialProperty`.

Optional fields:

* extensible metadata in key-value form.

The step MUST communicate that this is the beginning of a guided configuration, not an isolated property form.

#### Scenario: Valid property data allows continuation

- **GIVEN** the user enters a valid name, property type and address
- **WHEN** they choose to continue
- **THEN** the wizard advances to step 2
- **AND** the entered values remain available in later steps

#### Scenario: Missing required property data blocks continuation

- **GIVEN** one or more required fields are blank or invalid
- **WHEN** the user attempts to continue
- **THEN** the wizard remains on step 1
- **AND** field-level validation errors are shown

#### Scenario: Initial summary panel reflects entered property data

- **GIVEN** the user has entered property type, address and estimated units
- **WHEN** the auxiliary summary panel renders
- **THEN** it shows the current type, location summary and estimated unit count
- **AND** it shows a flow status indicating that structure is still pending

#### Scenario: Optional metadata does not block progression

- **GIVEN** required property fields are valid
- **WHEN** optional metadata is left empty
- **THEN** the user may continue to step 2

### Requirement: Step 2 defines optional property structure

Step 2 SHALL let the user choose how the property internal structure will be defined.

The user MUST be able to choose exactly one of:

1. no sections;
2. manual hierarchical structure;
3. quick repetitive structure generation.

#### Scenario: No sections skips hierarchical structure

- **GIVEN** the user selects "Sin secciones"
- **WHEN** they continue
- **THEN** the wizard records that units will belong only to the property
- **AND** step 3 does not require section placement for generated units

#### Scenario: Manual structure allows hierarchical sections

- **GIVEN** the user selects "Crear estructura manual"
- **WHEN** they add sections and nested sections
- **THEN** each section is persisted via `PropertySections::Create` on the draft property and shown in the workspace
- **AND** the user may edit or remove sections before continuing

#### Scenario: Quick structure is configured with parameters

- **GIVEN** the user selects "Crear estructura rápida"
- **WHEN** they provide parameters such as tower count, floors per tower and units per floor
- **THEN** the system generates an in-memory hierarchical preview from those parameters
- **AND** optional naming prefixes may refine generated section names

#### Scenario: Quick structure preview must be confirmed before continuing

- **GIVEN** the user configures quick structure parameters
- **WHEN** the preview is shown
- **THEN** the user can review the generated towers, floors and estimated leaf capacity
- **AND** the user must confirm the generated structure before advancing
- **AND** the preview counts reflect the configured parameters

#### Scenario: Structure step shows contextual preview panel

- **GIVEN** the user is defining structure in step 2
- **WHEN** any structure has been configured (real sections or in-memory quick preview)
- **THEN** an auxiliary preview panel shows the hierarchical tree
- **AND** summary counts such as towers, floors and estimated units are visible

#### Scenario: Empty manual structure blocks continuation

- **GIVEN** the user chose manual structure
- **WHEN** no section has been added
- **THEN** continuation is blocked
- **AND** an empty-state message explains that structure is required for this option

### Requirement: Step 3 defines how units will be created

Step 3 SHALL let the user choose how units for the property will be created and persisted during this step.

Supported modes:

1. create a single unit;
2. create multiple units, ideally using the structure from step 2;
3. import units from Excel through the existing bulk import flow.

The step MUST show contextual information from previous steps, including property name and structure summary when available.

#### Scenario: Automatic generation from structure is available when structure exists

- **GIVEN** step 2 produced a hierarchical structure
- **WHEN** the user opens step 3
- **THEN** they may choose to generate units automatically from that structure
- **AND** configuration fields such as unit type, identifier format and quantity per floor are available
- **AND** a live preview shows sample generated unit identifiers

#### Scenario: Single unit creation is available for simple cases

- **GIVEN** the user chooses individual unit creation
- **WHEN** they provide valid unit data
- **THEN** the unit is persisted via `Units::Create` on the draft property
- **AND** the unit is associated with the draft property and optional section

#### Scenario: Multiple unit creation uses structure context when present

- **GIVEN** the user chooses batch unit creation
- **WHEN** a structure exists from step 2
- **THEN** generation options use that structure as placement context
- **AND** the preview shows how many units will be created

#### Scenario: Excel import reuses existing bulk import behavior

- **GIVEN** the user chooses import from Excel
- **WHEN** they upload or select a file through the wizard
- **THEN** validation and parsing reuse the existing bulk import contract for units
- **AND** the wizard surfaces import errors, warnings and duplicates without duplicating domain rules in the client

#### Scenario: Unit step shows estimated creation summary

- **GIVEN** the user configured unit generation for 80 units
- **WHEN** the auxiliary summary renders
- **THEN** it states how many units will be created
- **AND** it explains the calculation basis when generation is automatic

#### Scenario: Unit validation errors are shown without losing wizard state

- **GIVEN** one or more units or import rows are invalid
- **WHEN** the user attempts to continue
- **THEN** the wizard remains on step 3
- **AND** errors, warnings or duplicates are shown per item or row
- **AND** previously persisted units and setup data remain intact

### Requirement: Step 4 presents an editable review summary

Before final confirmation, the wizard MUST show a clear summary of everything configured in prior steps.

The summary SHALL include:

* the persisted property (status `draft`);
* sections already created, when applicable;
* units already created or imported;
* errors;
* warnings;
* detected duplicates;
* omitted items, when applicable.

The summary MUST allow the user to return to earlier steps to correct information.

#### Scenario: Summary shows top-level cards and detailed sections

- **GIVEN** the user reaches step 4 with a valid draft property, sections and units
- **WHEN** the summary renders
- **THEN** top-level cards show property, structure, units and address at a glance
- **AND** detailed sections expand property data, structure tree and a units preview table

#### Scenario: Summary reflects warnings and duplicates

- **GIVEN** the setup contains non-blocking warnings or duplicate candidates
- **WHEN** the summary renders
- **THEN** warnings and duplicates are visible in the review
- **AND** the user can distinguish blocking errors from non-blocking issues

#### Scenario: User can navigate back from summary to fix data

- **GIVEN** the user identifies incorrect structure or units in the summary
- **WHEN** they go back to an earlier step and change data
- **THEN** the summary reflects the current state of the draft property, its sections and units

#### Scenario: Summary shows informational notice before confirmation

- **GIVEN** the user is reviewing a valid setup
- **WHEN** step 4 renders
- **THEN** an informational notice explains that sections and units may still be adjusted after confirmation through ordinary administration flows

### Requirement: Step 5 confirms setup and then shows completion actions

Step 5 SHALL first present a pre-confirmation state before transitioning the property from `draft` to `configured`. The property, its sections and its units are already persisted from prior steps; confirmation commits the lifecycle transition.
After successful confirmation, the same step SHALL transition to a completion state with next actions.

The screen MUST include:

* a ready-to-confirm state explaining that the property setup is ready to be finalized;
* a checklist of prepared elements;
* a compact final count summary;
* an auxiliary panel describing what will happen upon confirmation;
* an explicit confirmation control that requires user acknowledgment.

After successful confirmation, the system MUST show a completion state with clear next actions.

Suggested next actions:

* go to property detail;
* manage units;
* import owners;
* configure residents.

#### Scenario: Confirmation requires explicit acknowledgment

- **GIVEN** the user is on step 5
- **WHEN** the confirmation acknowledgment is not checked
- **THEN** the final confirm action remains disabled or rejected

#### Scenario: Successful confirmation transitions property to configured

- **GIVEN** the user confirms a valid setup draft
- **WHEN** the confirmation completes successfully
- **THEN** the draft property transitions from `status = draft` to `status = configured`
- **AND** all sections and units previously created during the wizard remain associated to the property
- **AND** the user sees a success completion state

#### Scenario: Completion screen offers next actions

- **GIVEN** setup confirmation succeeded
- **WHEN** the completion state renders
- **THEN** the user can navigate to the created property detail
- **AND** the user can continue with unit administration
- **AND** the user can start owner import
- **AND** the user can continue resident configuration

#### Scenario: Confirmation failure preserves draft for correction

- **GIVEN** the status transition fails due to a domain validation or authorization error
- **WHEN** confirmation is attempted
- **THEN** the property remains in `status = draft` with its sections and units intact
- **AND** the user receives actionable errors
- **AND** they may return to earlier steps or retry confirmation after correction

### Requirement: Wizard state is persisted incrementally and safely

The system SHALL persist wizard progress incrementally as the user advances through steps.

Step 1 completion persists the `ResidentialProperty` with `status = draft`. Steps 2 and 3 create `PropertySection` and `Unit` records directly on that draft property through existing domain services. Final confirmation transitions the property to `status = configured`.

The client MUST NOT be treated as the source of truth for `organization_id`, property ownership or cross-entity relationships.

#### Scenario: Step 1 persists property as draft

- **GIVEN** the user completes valid property data in step 1
- **WHEN** they continue to step 2
- **THEN** a `ResidentialProperty` record is created with `status = draft`
- **AND** the property is scoped to the authenticated organization

#### Scenario: Navigating back preserves earlier step data

- **GIVEN** the user completed steps 1 through 3
- **WHEN** they return to step 1 or 2 and then move forward again
- **THEN** previously entered values remain available
- **AND** dependent previews are recalculated from the current persisted draft state

#### Scenario: Wizard can be resumed after interruption

- **GIVEN** the user started the wizard and left it in progress
- **WHEN** they return to the setup flow later
- **THEN** the draft property and its configured sections and units are restored
- **AND** the wizard resumes at the last incomplete step

#### Scenario: Cancel on a draft property prompts the user to choose

- **GIVEN** the wizard is in progress and the property has `status = draft`
- **WHEN** the user presses Cancel
- **THEN** a confirmation modal is shown asking whether to delete the draft or keep it for later
- **AND** if the user chooses to delete, the draft property and its sections and units are removed and the user is returned to the properties index
- **AND** if the user chooses to keep, no records are modified and the user is returned to the properties index with the draft intact

#### Scenario: Cancel on a configured or active property returns to index

- **GIVEN** the wizard is open for a property with `status = configured` or `status = active`
- **WHEN** the user presses Cancel
- **THEN** the user is returned to the properties index without any destructive action

#### Scenario: Client cannot force organization ownership

- **GIVEN** a setup payload includes `organization_id` or foreign keys from another organization
- **WHEN** any wizard step is submitted or confirmed
- **THEN** the system ignores or rejects client-supplied organization ownership
- **AND** all created records belong to the authenticated organization context

#### Scenario: Refresh or resume keeps authorized draft scope

- **GIVEN** an authorized user resumes an in-progress setup
- **WHEN** the wizard state is restored
- **THEN** only their tenant-scoped draft property is accessible
- **AND** another organization's draft is not accessible

### Requirement: Each step validates before progression

The wizard MUST validate the active step before allowing forward navigation or final confirmation.

Validation rules MUST reuse existing domain contracts for property, section and unit data rather than inventing parallel client-only rules.

#### Scenario: Invalid property step blocks step 2

- **GIVEN** step 1 has validation errors
- **WHEN** the user attempts to continue
- **THEN** step 2 is not opened
- **AND** the errors remain visible on step 1

#### Scenario: Invalid structure option blocks step 3

- **GIVEN** the selected structure mode is incomplete or inconsistent
- **WHEN** the user attempts to continue from step 2
- **THEN** step 3 is not opened
- **AND** the user receives step-level errors or empty-state guidance

#### Scenario: Invalid units block summary progression

- **GIVEN** step 3 contains blocking unit or import errors
- **WHEN** the user attempts to continue to step 4
- **THEN** the wizard remains on step 3
- **AND** blocking errors are identified explicitly

#### Scenario: Summary blocks confirmation while blocking issues remain

- **GIVEN** step 4 still contains blocking errors
- **WHEN** the user attempts to continue to confirmation
- **THEN** progression is blocked
- **AND** the summary indicates which sections require correction

### Requirement: Wizard delegates all domain operations to existing services

Each wizard step MUST use the existing domain services and policies for property, section and unit operations. No domain rule is duplicated in the wizard layer.

- Step 1 persists the property via `Properties::Setup::InitializeDraft`.
- Steps 2 and 3 create sections and units via `PropertySections::Create` and `Units::Create`.
- Step 5 transitions the property via `Properties::Setup::Confirm` → `Properties::Setup::Configure`.

The wizard SHALL NOT bypass `ResidentialProperty`, `PropertySection`, `Unit` or bulk import authorization and validation rules.

#### Scenario: Property initialization uses domain contract

- **WHEN** the wizard completes Step 1 and advances
- **THEN** `Properties::Setup::InitializeDraft` creates the property with `status = draft`
- **AND** property normalization, uniqueness and lifecycle rules from `residential-property` are enforced
- **AND** the property is scoped to the current organization

#### Scenario: Section creation uses domain contract

- **GIVEN** the user adds sections in Step 2
- **WHEN** each section is created
- **THEN** `PropertySections::Create` is invoked on the draft property
- **AND** hierarchy, naming and eligibility rules from `property-section` are enforced
- **AND** every section belongs to the draft property in the current organization

#### Scenario: Unit creation and import use domain contract

- **GIVEN** the user creates or imports units in Step 3
- **WHEN** each unit is created
- **THEN** `Units::Create` or the existing bulk import path is invoked on the draft property
- **AND** identifier normalization, uniqueness and section eligibility rules from `unit` are enforced

### Requirement: Wizard UI text is fully internationalized

All user-visible wizard text MUST be internationalized in `es`, `en` and `pt`.

This includes step titles, descriptions, empty states, validation messages, summary labels, confirmation copy and next-action labels.

#### Scenario: Wizard renders in current locale

- **GIVEN** the application locale is `es`, `en` or `pt`
- **WHEN** any wizard step renders
- **THEN** visible text comes from i18n keys
- **AND** no hardcoded user-facing literals are shown

### Requirement: Property lifecycle progresses from draft to configured to active

A property created through the setup wizard SHALL follow a defined lifecycle that separates setup in progress, setup complete, and fully operational states.

| Status | Meaning | Mutable by section and unit services |
| --- | --- | --- |
| `draft` | Wizard in progress | Yes |
| `configured` | Wizard completed, pending explicit activation | Yes |
| `active` | Fully operational | Yes |
| `inactive` | Temporarily suspended | No |
| `archived` | Permanently retired | No |

Properties in `draft` and `configured` status SHALL be visible in the administrative property catalog for all users with permission to list properties, with a visible status badge distinguishing them from `active` properties.

Explicit activation from `configured` to `active` is a separate administrative action performed after wizard completion.

Editing a `configured` property does not revert it to `draft`.

#### Scenario: Draft property is visible in catalog with badge

- **GIVEN** a property exists with `status = draft`
- **WHEN** an authorized user views the property catalog
- **THEN** the draft property appears in the list
- **AND** a visual badge indicates its draft status

#### Scenario: Configured property is visible in catalog with badge

- **GIVEN** a property exists with `status = configured`
- **WHEN** an authorized user views the property catalog
- **THEN** the configured property appears in the list
- **AND** a visual badge distinguishes it from active properties

#### Scenario: Explicit activation transitions configured to active

- **GIVEN** a property has `status = configured`
- **WHEN** an authorized user performs the explicit activation action
- **THEN** the property transitions to `status = active`
- **AND** it becomes fully operational for all domain flows

#### Scenario: Draft and configured properties accept section and unit mutations

- **GIVEN** a property is in `draft` or `configured` status
- **WHEN** domain services for sections or units are invoked on it
- **THEN** the operations are accepted
- **AND** the property lifecycle gate does not block setup operations

#### Scenario: Inactive and archived properties reject mutations

- **GIVEN** a property is in `inactive` or `archived` status
- **WHEN** domain services for sections or units are invoked on it
- **THEN** the operations are rejected with a property lifecycle error

### Requirement: Reference mockups define the UX contract without prescribing pixel styling

The implementation MUST follow the functional and informational layout implied by:

* `mockups/improve-property-setup-flow/create-property-step-1.png`
* `mockups/improve-property-setup-flow/create-property-step-2.png`
* `mockups/improve-property-setup-flow/create-property-step-3.png`
* `mockups/improve-property-setup-flow/create-property-step-4.png`
* `mockups/improve-property-setup-flow/create-property-step-5.png`

The contract covers step hierarchy, content distribution between main and auxiliary panels, navigation affordances, preview behavior, summary structure and completion actions.

It does NOT require reproducing exact colors, spacing values or component styling beyond what is needed to satisfy the observable UX behavior.

#### Scenario: Step 2 matches option-card interaction model

- **GIVEN** the user is on the structure step
- **WHEN** structure mode options are shown
- **THEN** the three options are presented as mutually exclusive choices with title and helper description
- **AND** selecting one option reveals only the configuration controls relevant to that mode

#### Scenario: Step 3 matches method-selection and preview model

- **GIVEN** the user is on the units step
- **WHEN** unit creation methods are shown
- **THEN** the user selects one primary creation method at a time
- **AND** the main form and preview panel update according to the selected method

#### Scenario: Step 5 matches confirmation and consequence panel model

- **GIVEN** the user is on the confirmation step
- **WHEN** the screen renders
- **THEN** the main area shows readiness checklist and final counts
- **AND** the auxiliary panel explains the consequences of confirming
- **AND** the primary action is labeled as final confirmation, distinct from ordinary step continuation
