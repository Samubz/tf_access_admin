# residential-property Specification

## Purpose
TBD - created by archiving change improve-property-foundation. Update Purpose after archive.
## Requirements
### Requirement: Residential property belongs to organization

The system SHALL require every `ResidentialProperty` to belong to exactly one organization and SHALL derive that organization from trusted authenticated context during creation.

#### Scenario: Property is created in current organization

- **GIVEN** an authenticated tenant administrator operates in organization O
- **WHEN** a valid property is created
- **THEN** `organization_id` references O
- **AND** the client cannot assign a different organization

#### Scenario: Property without organization is rejected

- **GIVEN** no valid organization can be resolved
- **WHEN** property creation is attempted
- **THEN** creation is rejected
- **AND** no property is persisted

#### Scenario: Property organization cannot be changed

- **GIVEN** property P belongs to organization O
- **WHEN** an update attempts to move P to organization Q
- **THEN** the update is rejected
- **AND** P remains in O

### Requirement: Residential property requires valid name

The system SHALL require a non-empty property name and SHALL normalize it before validation and persistence.

#### Scenario: Valid name is normalized

- **GIVEN** an authorized user submits a property name with surrounding or repeated whitespace
- **WHEN** the property is validated
- **THEN** the canonical name is trimmed and whitespace is normalized

#### Scenario: Blank name is rejected

- **WHEN** an authorized user submits a blank or whitespace-only name
- **THEN** creation or update is rejected with a name validation error

### Requirement: Residential property name is unique within organization

The system SHALL enforce case-insensitive uniqueness of the normalized property name among non-deleted properties in the same organization and SHALL allow the same name in different organizations.

#### Scenario: Duplicate name in same organization is rejected

- **GIVEN** organization O has a non-deleted property named `Parque Central`
- **WHEN** another property in O is submitted as ` parque   central `
- **THEN** the operation is rejected with a name validation error
- **AND** no duplicate property is persisted

#### Scenario: Same name in different organizations is allowed

- **GIVEN** organization O has a property named `Parque Central`
- **WHEN** organization Q creates a valid property with the same normalized name
- **THEN** creation succeeds

#### Scenario: Concurrent duplicate creation is protected

- **GIVEN** two requests concurrently create the same normalized name in organization O
- **WHEN** both requests commit
- **THEN** at most one property is persisted
- **AND** the losing request receives a controlled domain validation error

### Requirement: Residential property has required type and location contract

The system SHALL require a valid `property_type` and SHALL preserve structured location fields plus extensible location metadata.

#### Scenario: Valid property type is accepted

- **WHEN** a property is submitted with a value from `PropertyTypes::ALL`
- **THEN** the type is persisted

#### Scenario: Unknown property type is rejected

- **WHEN** a property is submitted with an unknown `property_type`
- **THEN** the operation is rejected

#### Scenario: Location data is preserved

- **GIVEN** valid address, city, region, country, timezone, or supported location metadata
- **WHEN** the property is created or updated
- **THEN** the normalized location data is persisted without moving the property across organizations



### Requirement: Residential property can be archived instead of physically deleted

The system SHALL provide an explicit non-destructive archive operation that transitions an active or inactive property to `archived` while preserving its catalog, relationships, and history.

#### Scenario: Active property is archived

- **GIVEN** tenant administrator A may archive property P in the current organization
- **WHEN** A confirms archive
- **THEN** P becomes `archived`
- **AND** `deleted_at` is not used as the archive state
- **AND** dependent records remain persisted

#### Scenario: Archived property is not mutated through ordinary catalog flows

- **GIVEN** P is `archived`
- **WHEN** an ordinary create/update operation attempts to add or mutate dependent catalog data under P
- **THEN** the operation is denied unless a future explicit archived-property capability permits it

#### Scenario: Repeated archive is controlled

- **GIVEN** P is already `archived`
- **WHEN** archive is requested again
- **THEN** no destructive side effect occurs
- **AND** the service returns an idempotent success or controlled domain result

### Requirement: Residential property with dependencies cannot be hard-deleted

The system MUST prevent physical deletion of a property that has catalog, people-related, staff, visit, configuration, or operational dependencies.

#### Scenario: Sections or units block hard delete

- **GIVEN** P has at least one section or unit
- **WHEN** physical deletion is attempted
- **THEN** deletion is rejected
- **AND** P and its dependents remain persisted

#### Scenario: Person relationships block hard delete

- **GIVEN** a person is related to P through ownership, occupancy, or staff assignment
- **WHEN** physical deletion is attempted
- **THEN** deletion is rejected
- **AND** the person's relationships remain intact

#### Scenario: Future or active visits block hard delete

- **GIVEN** P has an active or future visit
- **WHEN** physical deletion is attempted
- **THEN** deletion is rejected
- **AND** the visit remains intact

#### Scenario: Archive remains available when dependencies exist

- **GIVEN** P has dependencies that block deletion
- **WHEN** an authorized tenant administrator archives P
- **THEN** archive may succeed without deleting those dependencies

### Requirement: Property creation and lifecycle use domain services

The system SHALL execute property creation, update, and archive through domain services rather than relying on controller-only business validation or direct lifecycle mutation.

#### Scenario: Create delegates to domain service

- **GIVEN** an authorized creation request
- **WHEN** the controller processes it
- **THEN** it invokes `Properties::Create`
- **AND** the service resolves organization, normalization, validation, authorization, and persistence

#### Scenario: Update delegates to domain service

- **GIVEN** an authorized update request for P
- **WHEN** the controller processes it
- **THEN** it invokes `Properties::Update`
- **AND** the controller does not decide name uniqueness or lifecycle rules

#### Scenario: Archive delegates to domain service

- **GIVEN** an authorized archive request for P
- **WHEN** the controller processes it
- **THEN** it invokes `Properties::Archive`
- **AND** does not call destructive cascade behavior as the archive implementation

#### Scenario: Direct request cannot bypass domain validation

- **GIVEN** frontend validation is absent or bypassed
- **WHEN** invalid property data reaches the backend
- **THEN** the same domain validations reject it

### Requirement: Tenant admin can manage properties in own organization

The system SHALL allow a tenant administrator to list, view, create, update, activate configured properties, and archive active or inactive properties only within the tenant administrator's organization.

#### Scenario: Tenant admin manages own organization property

- **GIVEN** user A is tenant admin of organization O
- **WHEN** A performs an allowed property operation on P in O
- **THEN** `Authorization::Resolver` and `ResidentialPropertyPolicy` authorize it

#### Scenario: Tenant admin cannot manage another organization

- **GIVEN** A is tenant admin of O
- **AND** P belongs to organization Q
- **WHEN** A attempts to view or mutate P
- **THEN** authorization is denied
- **AND** P is unchanged

### Requirement: Property admin access is scoped to assigned properties

The system SHALL derive property-administrator access exclusively from an active and currently valid `StaffAssignment` and SHALL scope `manage_property` to the assigned property.

#### Scenario: Assigned property admin views and updates property

- **GIVEN** user A's organizational `Person` has an active property-admin `StaffAssignment` for P
- **WHEN** A views or updates allowed descriptive data on P
- **THEN** authorization succeeds through `Authorization::Resolver` and Pundit

#### Scenario: Property admin cannot access unassigned property

- **GIVEN** A is assigned to P but not Q
- **WHEN** A attempts to view or update Q
- **THEN** authorization is denied
- **AND** policy scope excludes Q

#### Scenario: Inactive assignment grants no property-admin access

- **GIVEN** A's assignment for P is inactive, future-dated, or expired
- **WHEN** A attempts to manage P
- **THEN** authorization is denied

#### Scenario: Property admin cannot create or archive by default

- **GIVEN** A only has property-scoped `manage_property`
- **WHEN** A attempts to create a new property or archive P
- **THEN** authorization is denied
- **AND** `property_admin` is not treated as a global role

### Requirement: Residential property code is always system-derived

The system SHALL always derive `ResidentialProperty#code` on create. The derived code MUST use the property `property_type` abbreviation and a slug of the property `name`, remain within the alphanumeric-hyphen format, and be unique per organization among non-deleted properties. Any client-submitted `code` MUST be stripped and replaced by the derived value.

#### Scenario: Code is derived on create

- **GIVEN** organization O has no property with code `cdo-parque-central`
- **WHEN** a property is created in O with `name: "Parque Central"` and `property_type: condominium`
- **THEN** the persisted `code` is `cdo-parque-central`

#### Scenario: Derived code collision receives suffix

- **GIVEN** organization O already has a non-deleted property with `code: cdo-parque-central`
- **WHEN** another property in O is created whose type and name derive the same base code
- **THEN** the new property receives `code: cdo-parque-central-2`

#### Scenario: Client-submitted code is ignored

- **WHEN** a property is created via a user-facing form with `code: "MY-BLD"` in the request
- **THEN** the persisted `code` is the server-derived value, not `MY-BLD`

#### Scenario: Property rename does not change code

- **GIVEN** property P has `code: cdo-parque-central`
- **WHEN** P is renamed through a supported update path
- **THEN** P keeps `code: cdo-parque-central`

### Requirement: Cross-organization and unauthorized access are denied

The system MUST deny property access and mutations outside the actor's organization and effective capability scope.

#### Scenario: Cross-organization record is excluded from scope

- **GIVEN** user A operates in organization O
- **WHEN** `ResidentialPropertyPolicy::Scope` resolves
- **THEN** no property from another organization is returned

#### Scenario: User without permissions cannot manage property

- **GIVEN** user A has no organizational capability or active property assignment for P
- **WHEN** A attempts to list, view, create, update, archive, or delete property data
- **THEN** authorization is denied
- **AND** no mutation occurs

#### Scenario: Property capability does not leak between properties

- **GIVEN** A has `manage_property` for P
- **WHEN** authorization is evaluated for Q in the same request or session
- **THEN** P's capability is not reused for Q

### Requirement: Residential property has controlled status

The system SHALL limit property status to `draft`, `created`, `configured`, `active`, `inactive`, or `archived`.

`draft` represents wizard setup in progress. `created` represents wizard setup completed but still editable. `configured` represents confirmed setup. `active` represents fully operational property usage. `inactive` and `archived` represent non-operational states.

The setup wizard SHALL treat `created`, `configured`, and `active` as editable statuses for property identity fields, property type, building format, manual sections, and manual units. Property identity fields are `address_line`, `city`, `country`, `name`, `property_type`, `region`, and `timezone`.

The system SHALL derive `normalized_name` from `name` using the same normalization convention as `PropertySection#assign_normalized_name`. The system SHALL derive property `code` from the property type abbreviation and `normalized_name`, reusing the existing implemented code-generation convention. If a generated property `code` collides with another property, the system SHALL reject the change and tell the client that the property name must be changed.

Status transitions SHALL be constrained as follows: `draft` can transition to `created` or `configured`; `created` can transition to `configured`; `configured` can transition only to `active`; and `active` can transition only to `archived`.

Ordinary non-wizard property creation SHALL continue to default according to the ordinary creation flow. Wizard creation SHALL use `draft` initially and transition through the setup lifecycle.

#### Scenario: New property defaults to active

- **WHEN** an ordinary administrative property is created outside the setup wizard without specifying status
- **THEN** its status is `active`

#### Scenario: Wizard draft property starts as draft

- **WHEN** the setup wizard initializes a new property
- **THEN** its status is `draft`

#### Scenario: Setup can leave property created

- **GIVEN** a valid draft property completes setup without final confirmation
- **WHEN** the setup completion action chooses the editable outcome
- **THEN** the property transitions to `created`

#### Scenario: Setup can confirm property

- **GIVEN** a valid draft or created property is ready for confirmation
- **WHEN** the confirmation action is accepted
- **THEN** the property transitions to `configured`

#### Scenario: Unknown status is rejected

- **WHEN** create or update receives a status outside `draft`, `created`, `configured`, `active`, `inactive`, and `archived`
- **THEN** validation rejects the value

#### Scenario: Configured property can become active

- **GIVEN** an authorized actor manages configured property P
- **WHEN** they perform the explicit activation action
- **THEN** P becomes `active`

#### Scenario: Active property can become archived

- **GIVEN** an authorized actor manages active property P
- **WHEN** they archive P
- **THEN** P becomes `archived`

#### Scenario: Active property cannot become configured

- **GIVEN** property P has status `active`
- **WHEN** an actor attempts to transition P to `configured`
- **THEN** the transition is rejected

#### Scenario: Configured property cannot become created

- **GIVEN** property P has status `configured`
- **WHEN** an actor attempts to transition P to `created`
- **THEN** the transition is rejected

#### Scenario: Created property remains editable

- **GIVEN** property P has status `created`
- **WHEN** an authorized setup user edits P through the setup wizard
- **THEN** property fields, property type, structure format, manual sections, and manual units may be changed according to setup rules

#### Scenario: Configured property remains editable

- **GIVEN** property P has status `configured`
- **WHEN** an authorized setup user edits P through the setup wizard
- **THEN** property fields, property type, building format, manual sections, and manual units may be changed according to setup rules

#### Scenario: Active property remains editable

- **GIVEN** property P has status `active`
- **WHEN** an authorized setup user edits P through the setup wizard
- **THEN** property fields, property type, building format, manual sections, and manual units may be changed according to setup rules

#### Scenario: Name change regenerates normalized name and code

- **GIVEN** property P has a name-derived `normalized_name` and `code`
- **WHEN** an authorized setup user changes P's `name`
- **THEN** P's `normalized_name` is regenerated from the new `name`
- **AND** P's `code` is regenerated from P's property type abbreviation and regenerated `normalized_name`

#### Scenario: Name change with code collision is rejected

- **GIVEN** property P has status `created`, `configured`, or `active`
- **AND** changing P's `name` would generate a `code` already used by another property
- **WHEN** an authorized setup user submits the name change
- **THEN** the change is rejected
- **AND** the client is told to change the property name
