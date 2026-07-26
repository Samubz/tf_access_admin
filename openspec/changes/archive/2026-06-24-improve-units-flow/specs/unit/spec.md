# Unit

## MODIFIED Requirements

### Requirement: Unit identifier is unique inside its section context

The system SHALL enforce normalized-identifier uniqueness among non-soft-deleted
units sharing organization, property and section.

#### Scenario: Duplicate identifier in same section is rejected

- **GIVEN** section S contains unit `101`
- **WHEN** another non-deleted unit in S is submitted with an equivalent identifier
- **THEN** the operation is rejected
- **AND** no duplicate is persisted

#### Scenario: Same identifier in another section is allowed

- **GIVEN** section A contains unit `101`
- **WHEN** section B in the same property receives unit `101`
- **THEN** creation succeeds
- **AND** the sections distinguish both units

#### Scenario: Same identifier in another property is allowed

- **GIVEN** property P contains unit `101`
- **WHEN** property Q creates unit `101`
- **THEN** creation succeeds within Q's tenant-safe context

#### Scenario: Same identifier in another organization is allowed

- **GIVEN** organization O has property P with unit `101`
- **WHEN** organization Q creates unit `101` in one of its properties
- **THEN** creation succeeds within Q's tenant-safe context

#### Scenario: Concurrent duplicate creation is protected

- **GIVEN** two requests concurrently create the same normalized identifier in S
- **WHEN** both commit
- **THEN** at most one unit is persisted
- **AND** the losing request receives a controlled identifier error

### Requirement: Unit section must be eligible and operational

The system MUST require an assigned section to be effectively active and
eligible to contain units according to the `property-section` contract.

#### Scenario: Eligible section accepts unit

- **WHEN** section S is effectively active
- **AND** S is eligible to contain units according to the `property-section` contract
- **THEN** S may be assigned to a unit

#### Scenario: Non-eligible section rejects unit

- **WHEN** section S is not eligible to contain units according to the `property-section` contract
- **THEN** unit assignment is rejected with a `property_section_id` error

#### Scenario: Unit delegates section eligibility to property-section

- **GIVEN** the `property-section` contract marks section S as eligible for units
- **WHEN** Unit validates section eligibility
- **THEN** S may be assigned to the unit

#### Scenario: Unit rejects section not eligible by property-section

- **GIVEN** the `property-section` contract marks section S as not eligible for units
- **WHEN** Unit validates section eligibility
- **THEN** unit assignment is rejected with a `property_section_id` error

#### Scenario: Inactive or archived section rejects incoming unit

- **WHEN** S or one of its ancestors is not effectively active
- **THEN** create or move into S is rejected

### Requirement: Unit area must be positive when present

The system SHALL allow `area_m2` to be absent and SHALL require it to be greater
than zero when present.

#### Scenario: Positive area is accepted

- **WHEN** U is submitted with a positive decimal area
- **THEN** the area may be persisted

#### Scenario: Missing area is accepted

- **WHEN** U is submitted without `area_m2`
- **THEN** the area may remain null

#### Scenario: Zero or negative area is rejected

- **WHEN** U is submitted with `area_m2 <= 0`
- **THEN** validation rejects the area

### Requirement: Unit mutations use domain services

The system SHALL execute unit normalization, creation, descriptive update,
placement movement, archive and restore through the corresponding `Units::*`
services.

#### Scenario: Create uses service

- **WHEN** an authorized create request or import row is processed
- **THEN** it invokes `Units::Create`
- **AND** property, section, normalization, uniqueness and authorization are validated

#### Scenario: Update uses service

- **WHEN** descriptive unit data changes
- **THEN** it invokes `Units::Update`
- **AND** property and placement do not change implicitly

#### Scenario: Move uses service

- **WHEN** section placement changes
- **THEN** it invokes `Units::MoveToSection`
- **AND** target eligibility and uniqueness are revalidated

#### Scenario: Archive and restore use explicit services

- **WHEN** lifecycle operations are requested
- **THEN** the system invokes `Units::Archive` or `Units::Restore`
- **AND** generic update/destroy does not bypass lifecycle rules

#### Scenario: Bulk import cannot bypass domain rules

- **WHEN** a spreadsheet row creates a unit
- **THEN** bulk import delegates creation to `Units::Create`
- **AND** row processing does not maintain a divergent normalization or uniqueness rule

#### Scenario: Bulk import updates only when mode allows it

- **WHEN** a spreadsheet row matches an existing unit
- **AND** the import mode does not allow updates
- **THEN** the existing unit is not updated
- **AND** the row is reported according to the configured import mode

#### Scenario: Bulk import moves placement only when mode allows it

- **WHEN** a spreadsheet row would change a unit's section placement
- **AND** the import mode does not allow placement changes
- **THEN** the unit is not moved
- **AND** the row is rejected, skipped or warned according to the configured import mode

#### Scenario: Bulk import updates when mode allows it

- **WHEN** a spreadsheet row matches an existing unit
- **AND** the import mode allows updates
- **THEN** bulk import delegates descriptive changes to `Units::Update`

#### Scenario: Bulk import moves placement when mode allows it

- **WHEN** a spreadsheet row changes a unit's section placement
- **AND** the import mode allows placement changes
- **THEN** bulk import delegates placement changes to `Units::MoveToSection`

### Requirement: Unit authorization is property-scoped

The system SHALL evaluate `view_units` and `manage_units` against the concrete
residential property and SHALL deny cross-property or cross-organization access.

#### Scenario: Actor with view units can read unit catalog

- **GIVEN** actor A has `view_units` for property P
- **WHEN** A opens the unit catalog for P
- **THEN** units from P are visible according to the authorized scope

#### Scenario: Actor with view units but without manage units cannot mutate

- **GIVEN** actor A has `view_units` for property P
- **AND** A lacks `manage_units` for P
- **WHEN** A attempts to create, update, move, archive or restore a unit in P
- **THEN** authorization is denied
- **AND** no mutation occurs

#### Scenario: Tenant admin accesses unit in own organization

- **GIVEN** A is tenant admin of O
- **AND** property P belongs to O
- **WHEN** A performs a unit operation permitted by `view_units` or `manage_units`
- **THEN** authorization succeeds within P

#### Scenario: Assigned property admin manages unit

- **GIVEN** A has an active and valid StaffAssignment to P
- **AND** the assignment grants `manage_units`
- **WHEN** A creates, updates, moves, archives or restores a unit in P
- **THEN** authorization succeeds

#### Scenario: Assigned property admin reads unit catalog

- **GIVEN** A has an active and valid StaffAssignment to P
- **AND** the assignment grants `view_units`
- **WHEN** A opens the unit catalog for P
- **THEN** authorization succeeds for read scope

#### Scenario: Inactive assignment grants no access

- **GIVEN** A's assignment is inactive, future-dated or expired
- **WHEN** A attempts to manage a unit in P
- **THEN** authorization is denied

#### Scenario: Property admin role is not global

- **GIVEN** A manages units in P only
- **WHEN** A attempts to manage a unit in Q
- **THEN** authorization is denied
- **AND** Q is excluded from mutation scopes

#### Scenario: Assigned concierge can read only when granted view units

- **GIVEN** A has an active valid concierge assignment to P
- **AND** the assignment grants `view_units`
- **WHEN** A opens the unit catalog for P
- **THEN** authorization succeeds for read scope
- **AND** mutation actions remain denied without `manage_units`

#### Scenario: User without unit mutation capability cannot mutate

- **GIVEN** A lacks `manage_units` for P
- **WHEN** A attempts to create, update, move, archive or restore a unit in P
- **THEN** authorization is denied
- **AND** no mutation occurs

#### Scenario: Cross-organization unit is hidden

- **WHEN** `UnitPolicy::Scope` resolves
- **THEN** units from other organizations are excluded

#### Scenario: Property-scoped unit is hidden outside assignment

- **GIVEN** A has access to property P
- **AND** A has no access to property Q
- **WHEN** `UnitPolicy::Scope` resolves
- **THEN** units from P may be included
- **AND** units from Q are excluded

### Requirement: Unit is searchable within authorized scope

The system SHALL support tenant- and property-scoped lookup by identifier,
canonical normalized identifier, display name, section, type and status. Search
input is normalized by the system before matching against
`normalized_identifier`.

#### Scenario: Search input is normalized before lookup

- **WHEN** actor A searches for an identifier using different case, whitespace or Unicode representation
- **THEN** the system normalizes the input before matching `normalized_identifier`
- **AND** matching units are returned only within A's authorized scope

#### Scenario: Search returns only accessible property units

- **GIVEN** equivalent identifiers exist in properties P and Q
- **AND** actor A can access only P
- **WHEN** A searches the identifier
- **THEN** results contain the unit from P only

#### Scenario: Search does not leak another organization

- **WHEN** an actor searches units
- **THEN** no result from another organization is returned

#### Scenario: Searchable fields are stable

- **WHEN** a unit is serialized for an authorized catalog view
- **THEN** identifier, display name, type, status, property and section context are available
- **AND** sensitive relationship data is not included unless separately authorized

### Requirement: Unit update cannot bypass lifecycle operations

The system SHALL prevent generic descriptive updates from changing immutable
placement fields or executing lifecycle operations reserved for explicit
services.

#### Scenario: Update cannot change property or organization

- **GIVEN** unit U belongs to property P and organization O
- **WHEN** descriptive update submits another property or organization
- **THEN** the mutation is rejected or the untrusted values are ignored
- **AND** U remains in P and O

#### Scenario: Update cannot change section placement

- **GIVEN** unit U belongs to section A
- **WHEN** descriptive update submits section B
- **THEN** the update does not move U
- **AND** placement changes require `Units::MoveToSection`

#### Scenario: Update cannot archive unit

- **GIVEN** unit U is not archived
- **WHEN** descriptive update submits `status = archived`
- **THEN** the update is rejected
- **AND** archive requires `Units::Archive`

#### Scenario: Update can change operational status

- **WHEN** an authorized actor updates U from `available` to `occupied`, `inactive` or `maintenance`
- **THEN** the status change may be persisted according to the allowed status contract

### Requirement: Unit metadata is non-authoritative

The system SHALL allow `metadata` for extensible non-critical attributes, but
SHALL NOT use it as the source of truth for tenant, property, section,
identifier, uniqueness, lifecycle or authorization.

#### Scenario: Metadata cannot override structural fields

- **WHEN** metadata contains property, section, identifier, type, status or lifecycle values
- **THEN** those values do not override the dedicated Unit columns

#### Scenario: Metadata cannot grant authorization

- **WHEN** metadata contains role, capability or access information
- **THEN** authorization ignores metadata
- **AND** access is resolved through the authorization contract

### Requirement: Unit mutations respect property lifecycle

The system SHALL reject ordinary unit mutations when the residential property
lifecycle does not allow catalog changes.

#### Scenario: Archived property rejects ordinary unit mutation

- **GIVEN** property P is archived
- **WHEN** create, update, move, archive or restore is attempted for a unit in P
- **THEN** the mutation is denied according to property lifecycle rules
