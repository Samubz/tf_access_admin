## Purpose

Define the tenant-scoped residential property detail experience, including persisted property data, lifecycle-aware actions, read-only structure display, and recommended next actions.

## Requirements

### Requirement: Property detail page shows persisted property configuration

The system SHALL expose a tenant-scoped property detail page for authorized users. The page SHALL show persisted property details, summary cards, structure/unit counts, recommended next actions, and the structure/unit preview using the same persisted data contract as the setup wizard preview and confirmation step.

The detail page SHALL follow the main layout implied by `mockups/view-property-details/edit-view.png`: breadcrumb/header, page title, summary cards, general information, structure/sections map, and recommended next actions. The right-side aside shown in the mockup SHALL NOT be implemented in this change. Until the aside is implemented, the page SHALL render as a single full-width column and SHALL NOT reserve an empty aside region.

If a property has no sections, the detail page SHALL NOT render the property structure section. Summary cards and general information SHALL still render with default or null values, such as `0` for counts and empty/null display for unavailable values.

#### Scenario: Authorized user opens property detail

- **GIVEN** user A has permission to view property P in organization O
- **WHEN** A opens P's detail page
- **THEN** the page renders P's persisted name, type, status, address, organization, created/updated timestamps, structure counts, and unit counts
- **AND** all data is scoped to organization O and property P

#### Scenario: Cross-organization property is denied

- **GIVEN** user A operates in organization O
- **AND** property P belongs to organization Q
- **WHEN** A attempts to open P's detail page
- **THEN** access is denied
- **AND** no property, section, or unit data from Q is returned

#### Scenario: Detail counts match wizard persisted preview

- **GIVEN** property P has persisted sections and units
- **WHEN** an authorized user opens P's detail page
- **THEN** structure and unit totals match the totals produced by the wizard persisted preview/confirmation data contract
- **AND** archived or soft-deleted records hidden from the wizard are also hidden from the detail counts

#### Scenario: Aside is not rendered

- **GIVEN** an authorized user opens P's detail page
- **WHEN** the page renders
- **THEN** the main detail content is shown
- **AND** the mockup's right-side aside panels are not rendered
- **AND** no empty aside space is reserved

#### Scenario: Property without sections hides structure section

- **GIVEN** property P has no persisted visible sections
- **WHEN** an authorized user opens P's detail page
- **THEN** the property structure section is not rendered
- **AND** summary values use defaults or null display values such as `0` for section and unit counts

### Requirement: Property detail actions are lifecycle-aware

The detail page SHALL show the primary edit action only for properties with status `draft` or `created`. Properties with status `configured` or `active` SHALL NOT show the primary edit action on the detail page. Inactive and archived properties SHALL NOT show setup edit actions.

The page SHALL show only actions the current user is authorized to perform for the specific property.

#### Scenario: Draft property shows primary edit action

- **GIVEN** property P has status `draft`
- **AND** user A is authorized to edit setup for P
- **WHEN** A opens P's detail page
- **THEN** the primary edit action is visible
- **AND** activating it opens the setup wizard for P

#### Scenario: Created property shows primary edit action

- **GIVEN** property P has status `created`
- **AND** user A is authorized to edit setup for P
- **WHEN** A opens P's detail page
- **THEN** the primary edit action is visible
- **AND** activating it opens the setup wizard for P

#### Scenario: Configured property hides primary edit action

- **GIVEN** property P has status `configured`
- **WHEN** an authorized user opens P's detail page
- **THEN** the primary edit action is not visible

#### Scenario: Active property hides primary edit action

- **GIVEN** property P has status `active`
- **WHEN** an authorized user opens P's detail page
- **THEN** the primary edit action is not visible

#### Scenario: Unauthorized user does not see edit action

- **GIVEN** user A can view property P
- **AND** A is not authorized to edit setup for P
- **WHEN** A opens P's detail page
- **THEN** no setup edit action is visible

### Requirement: Detail structure map is read-only except unit actions

The property detail structure map SHALL display sections and units from the wizard preview tree in read-only mode for sections. The detail page MUST NOT show "Agregar sección raíz", section creation controls, section edit controls, section move controls, or section row action menus.

Only unit rows MAY expose an action menu, and that menu SHALL contain only the existing wizard step 3 "Gestionar unidad" action for navigating to the unit detail page. Detail mode MUST NOT inherit unit edit or delete actions from wizard unit row components.

#### Scenario: Root section creation is absent

- **GIVEN** an authorized user opens P's detail page
- **WHEN** the structure/sections map renders
- **THEN** no "Agregar sección raíz" action is shown
- **AND** no section creation control is present

#### Scenario: Section rows have no actions

- **GIVEN** P has persisted sections
- **WHEN** the structure/sections map renders
- **THEN** section rows are visible as read-only hierarchy nodes
- **AND** section rows do not expose edit, move, delete, or action-menu controls

#### Scenario: Unit rows expose manage-unit action

- **GIVEN** P has persisted unit U visible in the detail structure map
- **AND** user A is authorized to view or manage U according to the existing unit detail policy
- **WHEN** A opens U's row action menu
- **THEN** the "Gestionar unidad" action from wizard step 3 is available
- **AND** activating it navigates to U's existing unit detail page for property P

#### Scenario: Unit rows do not expose edit or delete actions

- **GIVEN** P has persisted unit U visible in the detail structure map
- **WHEN** the detail unit row action menu renders
- **THEN** unit edit is not available
- **AND** unit delete is not available

#### Scenario: Unit action respects authorization

- **GIVEN** P has persisted unit U visible in the detail structure map
- **AND** user A is not authorized to access U's unit detail page
- **WHEN** A opens P's detail page
- **THEN** U's manage-unit action is not visible

### Requirement: Property detail next actions mirror confirmation actions

The detail page SHALL show the relevant next-action options from the wizard step 5 confirmation/completion context in the "Proximos pasos recomendados" section, filtered by property status and user authorization. These are follow-up options, not step 5 save or confirmation controls.

The wizard step 5 `property_detail` next-action SHALL link to the property detail page introduced by this change instead of the setup wizard edit route. The `reopen_setup` next-action remains the dedicated entry point back into the wizard and SHALL be unaffected by this change.

#### Scenario: Detail page shows recommended next actions

- **GIVEN** user A is authorized for follow-up actions on property P
- **WHEN** A opens P's detail page
- **THEN** the page shows recommended actions such as unit administration, owner import, resident configuration, or history when available for A and P

#### Scenario: Wizard property_detail action links to the new detail page

- **GIVEN** property P has completed wizard step 5
- **WHEN** a user views the "property_detail" next-action on the step 5 completion screen
- **THEN** its link points to P's property detail page
- **AND** it no longer points to the setup wizard edit route

#### Scenario: Next actions are hidden when unauthorized

- **GIVEN** user A can view property P
- **AND** A lacks authorization for one recommended follow-up action
- **WHEN** A opens P's detail page
- **THEN** that unauthorized action is not shown
