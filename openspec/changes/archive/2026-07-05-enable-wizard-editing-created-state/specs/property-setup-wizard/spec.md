## ADDED Requirements

### Requirement: Wizard supports editable existing properties

The setup wizard SHALL support reopening existing `created`, `configured`, and `active` properties for editing from step 1. These statuses SHALL allow authorized users to edit property identity fields, property type, building format, manual sections, and manual units.

Property identity fields are `address_line`, `city`, `country`, `name`, `property_type`, `region`, and `timezone`. The property `normalized_name` SHALL be derived from `name` using the same normalization convention as `PropertySection#assign_normalized_name`. The property `code` SHALL be derived from the property type abbreviation and `normalized_name`, reusing the existing implemented code-generation convention. If the generated property `code` collides with another property, the change SHALL be rejected and the client SHALL be told to change the property name.

Building format SHALL mean the `PropertyStructureFormat` catalog introduced by `2026-06-29-improve-property-structure-wizard-formats`, including the catalog entries that define section levels and `units_in`.

For `created`, `configured`, and `active` properties, the wizard SHALL offer only manual section and manual unit management modes; quick automatic structure and automatic unit generation SHALL NOT be offered.

#### Scenario: Created property reopens all setup fields

- **GIVEN** property P has status `created`
- **WHEN** an authorized setup user opens P in the wizard
- **THEN** property data fields are editable
- **AND** property type and building format controls are editable
- **AND** manual section and manual unit management are available

#### Scenario: Configured property reopens all setup fields

- **GIVEN** property P has status `configured`
- **WHEN** an authorized setup user opens P in the wizard
- **THEN** property data fields are editable
- **AND** property type and building format controls are editable
- **AND** manual section and manual unit management are available

#### Scenario: Active property reopens all setup fields

- **GIVEN** property P has status `active`
- **WHEN** an authorized setup user opens P in the wizard
- **THEN** property data fields are editable
- **AND** property type and building format controls are editable
- **AND** manual section and manual unit management are available

#### Scenario: Existing property edit sessions start at step 1

- **GIVEN** property P has status `created`, `configured`, or `active`
- **WHEN** an authorized setup user opens P in the wizard
- **THEN** the wizard opens on step 1

#### Scenario: Existing property edit sessions are manual-only

- **GIVEN** property P has status `created`, `configured`, or `active`
- **WHEN** the user opens structure or unit steps in the wizard
- **THEN** quick automatic structure generation is not offered
- **AND** automatic unit generation is not offered
- **AND** manual section and manual unit paths are the available edit paths

#### Scenario: Name change regenerates normalized name and code

- **GIVEN** property P has a name-derived `normalized_name` and `code`
- **WHEN** an authorized setup user changes P's `name`
- **THEN** P's `normalized_name` is regenerated from the new `name`
- **AND** P's `code` is regenerated from P's property type abbreviation and regenerated `normalized_name`

#### Scenario: Name change with code collision is rejected

- **GIVEN** changing property P's `name` would generate a property `code` already used by another property
- **WHEN** an authorized setup user submits the name change
- **THEN** the change is rejected
- **AND** the client is told to change the property name

### Requirement: Step 3 unit actions link to the unit detail page

Each unit row's action menu in wizard step 3 SHALL offer a "manage unit" action that navigates the user to that unit's existing detail page (`/admin/residential_properties/:residential_property_id/units/:unit_id`), outside the wizard.

#### Scenario: Setup user opens a unit's detail page from step 3

- **GIVEN** property P has a persisted unit U shown in wizard step 3
- **WHEN** an authorized setup user selects "manage unit" for U
- **THEN** the browser navigates to U's unit detail page for property P

### Requirement: The standalone structure page is retired in favor of the wizard

The standalone, non-wizard property structure page (previously `/admin/residential_properties/:id/structure`) and its dedicated controller SHALL be removed, since the setup wizard now covers section/unit management (including manual section moves and archive) for `draft`, `created`, `configured`, and `active` properties. Domain services previously invoked only through that page's dedicated mutation controller (`PropertySections::Create`, `PropertySections::Update`, `PropertySections::Move`, `PropertySections::Archive`) SHALL be preserved and invoked through the wizard's own controller actions instead. Any other entry point that previously linked to the standalone structure page (such as the organization-wide section directory's edit action) SHALL be updated to link into the setup wizard instead.

#### Scenario: Organization-wide section directory links into the wizard

- **GIVEN** an authorized user opens the organization-wide section directory and selects "edit" for a section belonging to property P
- **WHEN** the edit action is triggered
- **THEN** the user is redirected into P's setup wizard instead of the removed standalone structure page

#### Scenario: Standalone structure page and its controller no longer exist

- **WHEN** a request is made to the previous standalone structure route
- **THEN** the route no longer resolves to a dedicated structure page or controller

### Requirement: Archived sections and units are hidden from the wizard

Sections or units whose effective status is `archived` (their own status, or the status of their nearest archived ancestor section) SHALL NOT appear in wizard structure trees, unit lists, or persisted summary/preview counts (steps 2 through 5). This filter is specific to the wizard; it does not change how archived sections/units are shown in ordinary, non-wizard section/unit administration.

#### Scenario: Archived section is excluded from the wizard structure tree

- **GIVEN** property P has an archived section
- **WHEN** an authorized user opens P's wizard structure step
- **THEN** the archived section is not shown in the structure tree

#### Scenario: Units under an archived section are excluded from the wizard

- **GIVEN** property P has an archived section with non-archived, non-deleted units
- **WHEN** an authorized user opens P's wizard unit or summary steps
- **THEN** those units are not shown, counted, or included in the nested preview

#### Scenario: Archived unit is excluded from wizard summary and confirmation counts

- **GIVEN** property P has an archived unit under a non-archived section
- **WHEN** an authorized user opens P's step 4 summary or step 5 confirmation
- **THEN** the archived unit is not counted or shown in the nested preview

### Requirement: Structure-affecting edits require destructive reset confirmation

The system SHALL treat property type and structure mode as the only two reset triggers. Building format has no value independent of property type: it is derived from `property_type` (via the existing `PropertyStructureFormat` catalog resolution), with only the `skip_top_level` toggle as a variation, which is itself part of structure-mode configuration, so "building format" SHALL NOT be treated as a separate reset trigger.

When a draft, created, configured, or active property already has sections or units, changing property type or structure mode SHALL require an explicit confirmation dialog before the system resets existing configured structure.

If the user confirms for a `draft` property, the system SHALL really destroy the current property's existing sections and units in an all-or-nothing operation scoped to the current organization and property, then apply the new property type or structure-mode choice.

If the user confirms for a `created`, `configured`, or `active` property, the system SHALL remove the current property's existing sections and their associated units in an all-or-nothing operation scoped to the current organization and property, then apply the new property type or structure-mode choice. Each section (with its associated units) is soft-deleted directly when it has no operational history, or archived when it or any of its units has operational history, per the operational-history rule defined in the `manual-structure-builder` and `unit` capabilities.

If the user cancels, no property type, structure, section, or unit changes SHALL be persisted.

#### Scenario: Draft step 1 property type change prompts reset

- **GIVEN** a draft property has persisted sections or units
- **WHEN** the user returns from step 3 to step 1 and changes property type
- **THEN** the wizard shows a confirmation dialog explaining that the configured structure will be deleted
- **AND** no destructive request is sent until the user confirms

#### Scenario: Draft step 2 structure mode change prompts reset

- **GIVEN** a draft property has persisted sections or units
- **WHEN** the user returns from step 3 to step 2 and changes structure mode (including a format-affecting quick-structure option such as `skip_top_level`)
- **THEN** the wizard shows a confirmation dialog explaining that the configured structure will be deleted
- **AND** no destructive request is sent until the user confirms

#### Scenario: Existing property structure-affecting change prompts reset

- **GIVEN** property P has status `created`, `configured`, or `active`
- **AND** P has persisted sections or units
- **WHEN** the user changes property type or structure mode
- **THEN** the wizard shows a confirmation dialog explaining that the configured structure will be reset
- **AND** no destructive request is sent until the user confirms

#### Scenario: Confirmed draft reset really destroys existing structure

- **GIVEN** a draft property has persisted sections and units
- **WHEN** the user confirms a structure-affecting change
- **THEN** all existing sections for that property are really destroyed
- **AND** all existing units for that property are really destroyed
- **AND** the new property type, building format, or structure-mode choice is persisted

#### Scenario: Confirmed existing property reset soft-deletes structure without operational history

- **GIVEN** property P has status `created`, `configured`, or `active`
- **AND** P has persisted sections and units, none of which have any operational history
- **WHEN** the user confirms a structure-affecting change
- **THEN** all existing sections for P are soft-deleted
- **AND** all units associated with those sections are soft-deleted
- **AND** the new property type or structure-mode choice is persisted

#### Scenario: Confirmed existing property reset archives structure with operational history

- **GIVEN** property P has status `created`, `configured`, or `active`
- **AND** P has a section whose unit has operational history (`unit_ownerships`, `lease_contracts`, `unit_occupancies`, or `visits`)
- **WHEN** the user confirms a structure-affecting change
- **THEN** that section and its units are archived rather than soft-deleted
- **AND** sections/units elsewhere in P without operational history are soft-deleted
- **AND** the new property type or structure-mode choice is persisted

#### Scenario: Cancelled reset preserves existing structure

- **GIVEN** a draft, created, configured, or active property has persisted sections and units
- **WHEN** the user cancels the structure reset confirmation
- **THEN** existing sections and units remain unchanged
- **AND** the previous property type, building format, and structure mode remain unchanged

## MODIFIED Requirements

### Requirement: Step 5 confirms setup and then shows completion actions

Step 5 SHALL first present a pre-completion state for a valid setup. The property, its sections and its units are already persisted from prior steps. For `draft` setup, the user SHALL choose whether to finish as `created` or confirm as `configured`. For `created` setup edits, the user MAY save changes while remaining `created` or confirm as `configured`. For `configured` and `active` setup edits, saving wizard changes SHALL preserve the current status, and the `configured` confirmation control SHALL NOT be offered.

Choosing `created` completes the wizard while keeping the property editable through the wizard. Choosing `configured` confirms setup while still allowing future wizard editing under the status-specific reset rules, but only `draft` and `created` properties may transition to `configured`. `configured` properties can transition only to `active` through the explicit activation action outside the wizard. `active` properties are final for wizard purposes and can transition only to `archived` through archival. After any successful outcome, the same step SHALL transition to a completion state with next actions.

The screen MUST include:

* a ready-to-complete state explaining what saving will do;
* a checklist of prepared elements;
* a compact final count summary;
* an auxiliary panel describing the consequences of the available outcome(s);
* for `draft` and `created` setup, explicit controls for saving as created and confirming as configured;
* for `configured` and `active` setup, a single explicit save control that preserves the current status, with no configured-confirmation control shown.

After successful completion, the system MUST show a completion state with clear next actions.

Suggested next actions:

* go to property detail;
* reopen setup editing when the property is `created`, `configured`, or `active`;
* manage units;
* import owners;
* configure residents.

#### Scenario: Confirmation requires explicit acknowledgment

- **GIVEN** the user is on step 5 and chooses the configured outcome
- **WHEN** the confirmation acknowledgment is not checked
- **THEN** the final confirm action remains disabled or rejected

#### Scenario: Successful created completion transitions property to created

- **GIVEN** the user completes a valid setup draft
- **WHEN** they choose to save it as editable
- **THEN** the draft property transitions from `status = draft` to `status = created`
- **AND** all sections and units previously created during the wizard remain associated to the property
- **AND** the user sees a success completion state

#### Scenario: Created edit saved without confirmation remains created

- **GIVEN** property P has status `created`
- **WHEN** the user edits P through the wizard and saves without choosing configured confirmation
- **THEN** P remains in `status = created`
- **AND** the edited property, sections, and units remain associated to P

#### Scenario: Configured edit saved through wizard remains configured

- **GIVEN** property P has status `configured`
- **WHEN** the user opens step 5 for P
- **THEN** the configured-confirmation control is not shown
- **AND** only a save control that preserves the current status is shown
- **WHEN** the user edits P through the wizard and saves
- **THEN** P remains in `status = configured`
- **AND** the edited property, sections, and units remain associated to P

#### Scenario: Active edit saved through wizard remains active

- **GIVEN** property P has status `active`
- **WHEN** the user opens step 5 for P
- **THEN** the configured-confirmation control is not shown
- **AND** only a save control that preserves the current status is shown
- **WHEN** the user edits P through the wizard and saves
- **THEN** P remains in `status = active`
- **AND** the edited property, sections, and units remain associated to P

#### Scenario: Draft or created step 5 offers the configured-confirmation control

- **GIVEN** property P has status `draft` or `created`
- **WHEN** the user opens step 5 for P
- **THEN** both a save-as-created control and a confirm-as-configured control are shown

#### Scenario: Successful confirmation transitions property to configured

- **GIVEN** the user confirms a valid setup draft or created property
- **WHEN** the confirmation completes successfully
- **THEN** the property transitions to `status = configured`
- **AND** all sections and units previously created during the wizard remain associated to the property
- **AND** the user sees a success completion state

#### Scenario: Active property cannot be confirmed back to configured

- **GIVEN** property P has status `active`
- **WHEN** the user attempts to confirm P as configured through the wizard
- **THEN** the transition is rejected
- **AND** P remains in `status = active`

#### Scenario: Completion screen offers next actions

- **GIVEN** setup completion succeeded
- **WHEN** the completion state renders
- **THEN** the user can navigate to the created property detail
- **AND** the user can continue with unit administration
- **AND** the user can start owner import
- **AND** the user can continue resident configuration

#### Scenario: Confirmation failure preserves editable state for correction

- **GIVEN** the status transition fails due to a domain validation or authorization error
- **WHEN** completion or confirmation is attempted
- **THEN** the property remains in its previous status with its sections and units intact
- **AND** the user receives actionable errors
- **AND** they may return to earlier editable steps or retry after correction

### Requirement: Wizard state is persisted incrementally and safely

The system SHALL persist wizard progress incrementally as the user advances through steps.

Step 1 completion persists the `ResidentialProperty` with `status = draft` for new setup. Steps 2 and 3 create `PropertySection` and `Unit` records directly on that setup property through existing domain services. Step 5 may transition the property to `created` or `configured`.

For `created`, `configured`, and `active` properties, steps 1 through 3 remain editable according to setup rules. Existing property edit sessions SHALL open on step 1.

The client MUST NOT be treated as the source of truth for `organization_id`, property ownership or cross-entity relationships.

#### Scenario: Step 1 persists property as draft

- **GIVEN** the user completes valid property data for a new setup
- **WHEN** they continue to step 2
- **THEN** a `ResidentialProperty` record is created with `status = draft`
- **AND** the property is scoped to the authenticated organization

#### Scenario: Navigating back preserves earlier step data

- **GIVEN** the user completed steps 1 through 3
- **WHEN** they return to step 1 or 2 and then move forward again without a structure-affecting change
- **THEN** previously entered values remain available
- **AND** dependent previews are recalculated from the current persisted setup state

#### Scenario: Wizard can be resumed after interruption

- **GIVEN** the user started the wizard and left it in progress
- **WHEN** they return to the setup flow later
- **THEN** the draft property and its configured sections and units are restored
- **AND** the wizard resumes at the last incomplete step

#### Scenario: Created property can be reopened for editing

- **GIVEN** a property exists with `status = created`
- **WHEN** an authorized user opens it in the setup wizard
- **THEN** the persisted property, sections, and units are restored
- **AND** editable steps are available according to created-property rules

#### Scenario: Configured property can be reopened for editing

- **GIVEN** a property exists with `status = configured`
- **WHEN** an authorized user opens it in the setup wizard
- **THEN** the persisted property, sections, and units are restored
- **AND** the wizard opens on step 1 with editable steps available according to configured-property rules

#### Scenario: Active property can be reopened for editing

- **GIVEN** a property exists with `status = active`
- **WHEN** an authorized user opens it in the setup wizard
- **THEN** the persisted property, sections, and units are restored
- **AND** the wizard opens on step 1 with editable steps available according to active-property rules

#### Scenario: Cancel on a draft property prompts the user to choose

- **GIVEN** the wizard is in progress and the property has `status = draft`
- **WHEN** the user presses Cancel
- **THEN** a confirmation modal is shown asking whether to delete the draft or keep it for later
- **AND** if the user chooses to delete, the draft property and its sections and units are removed and the user is returned to the properties index
- **AND** if the user chooses to keep, no records are modified and the user is returned to the properties index with the draft intact

#### Scenario: Cancel on a created or configured property returns without destructive action

- **GIVEN** the wizard is open for a property with `status = created`, `configured`, or `active`
- **WHEN** the user presses Cancel
- **THEN** the user is returned to the properties index without any destructive action

#### Scenario: Client cannot force organization ownership

- **GIVEN** a setup payload includes `organization_id` or foreign keys from another organization
- **WHEN** any wizard step is submitted or confirmed
- **THEN** the system ignores or rejects client-supplied organization ownership
- **AND** all created records belong to the authenticated organization context

#### Scenario: Refresh or resume keeps authorized setup scope

- **GIVEN** an authorized user resumes setup for a draft, created, configured, or active property
- **WHEN** the wizard state is restored
- **THEN** only their tenant-scoped setup property is accessible
- **AND** another organization's property is not accessible

### Requirement: Property lifecycle progresses from draft to configured to active

A property created through the setup wizard SHALL follow a defined lifecycle that separates setup in progress, editable setup output, confirmed setup, and fully operational states.

| Status | Meaning | Property fields/type editable in wizard | Manual sections/units mutable |
| --- | --- | --- | --- |
| `draft` | Wizard in progress | Yes | Yes |
| `created` | Wizard completed, still editable | Yes | Yes |
| `configured` | Wizard confirmed, pending explicit activation | Yes | Yes |
| `active` | Fully operational | Yes | Yes |
| `inactive` | Temporarily suspended | No | No |
| `archived` | Permanently retired | No | No |

Properties in `draft`, `created`, and `configured` status SHALL be visible in the administrative property catalog for all users with permission to list properties, with visible status badges distinguishing them from `active` properties.

Explicit activation from `configured` to `active` is a separate administrative action performed after wizard confirmation. `configured` properties SHALL NOT transition back to `created`. `active` properties SHALL NOT transition back to `configured`; they can only transition to `archived`.

Editing a `configured` or `active` property through the wizard does not revert it to `draft` or `created`.

#### Scenario: Draft property is visible in catalog with badge

- **GIVEN** a property exists with `status = draft`
- **WHEN** an authorized user views the property catalog
- **THEN** the draft property appears in the list
- **AND** a visual badge indicates its draft status

#### Scenario: Created property is visible in catalog with badge

- **GIVEN** a property exists with `status = created`
- **WHEN** an authorized user views the property catalog
- **THEN** the created property appears in the list
- **AND** a visual badge indicates its editable setup status

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

#### Scenario: Draft created configured and active properties accept setup section and unit mutations

- **GIVEN** a property is in `draft`, `created`, `configured`, or `active` status
- **WHEN** domain services for sections or units are invoked through authorized setup/manual administration paths
- **THEN** the operations are accepted according to the status editability rules

#### Scenario: Inactive and archived properties reject mutations

- **GIVEN** a property is in `inactive` or `archived` status
- **WHEN** domain services for sections or units are invoked on it
- **THEN** the operations are rejected with a property lifecycle error
