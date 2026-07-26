# Unit

## Purpose

Define the tenant-safe identity, placement, uniqueness, lifecycle, service and
authorization contract for units within a residential property.

## ADDED Requirements

### Requirement: Unit belongs to organization and residential property

The system SHALL require every `Unit` to belong to exactly one organization and
one residential property whose organization matches the unit organization.

#### Scenario: Unit derives organization from property

- **GIVEN** property P belongs to organization O
- **WHEN** an authorized actor creates a unit in P
- **THEN** the unit references P and O
- **AND** organization is derived from trusted property context

#### Scenario: Unit without property is rejected

- **WHEN** unit creation has no valid residential property
- **THEN** creation is rejected
- **AND** no unit is persisted

#### Scenario: Organization mismatch is rejected or ignored

- **GIVEN** property P belongs to organization O
- **WHEN** a create or update request submits organization Q
- **THEN** the system does not persist Q on the unit
- **AND** the unit organization remains derived from P
- **AND** the request is rejected when the mismatch indicates an invalid mutation attempt

#### Scenario: Client cannot change property or organization

- **GIVEN** unit U belongs to property P in organization O
- **WHEN** update or move submits another property or organization
- **THEN** the untrusted values are ignored or rejected
- **AND** U remains in P and O

### Requirement: Unit may belong to one section in the same property

The system SHALL allow a unit to have no section or one non-deleted section
belonging to the same organization and residential property.

#### Scenario: Unit without section is accepted

- **GIVEN** active property P
- **WHEN** an authorized actor creates U without `property_section_id`
- **THEN** U is persisted in the property-level context

#### Scenario: Unit with valid section is accepted

- **GIVEN** eligible and effectively active section S belongs to P
- **WHEN** an authorized actor creates U with S
- **THEN** U references S and P

#### Scenario: Section from another property is rejected

- **GIVEN** U belongs to P
- **AND** section S belongs to Q
- **WHEN** S is submitted for U
- **THEN** the operation is rejected with a `property_section_id` error
- **AND** U is not silently treated as having no section

#### Scenario: Section from another organization is rejected

- **GIVEN** U is being created in organization O
- **AND** section S belongs to organization Q
- **WHEN** S is submitted
- **THEN** the operation is rejected without exposing foreign section data

#### Scenario: Missing section identifier is rejected

- **WHEN** a non-blank but unknown `property_section_id` is submitted
- **THEN** the operation is rejected
- **AND** no property-level unit is created accidentally

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

#### Scenario: Current eligible section types are delegated to property-section

- **GIVEN** the current `property-section` contract marks `block`, `tower`, and `floor` as eligible for units
- **WHEN** Unit validates section eligibility
- **THEN** Unit relies on the `property-section` eligibility contract
- **AND** Unit does not hardcode an independent section-type list

#### Scenario: Inactive or archived section rejects incoming unit

- **WHEN** S or one of its ancestors is not effectively active
- **THEN** create or move into S is rejected

### Requirement: Unit identifier is normalized canonically

The system SHALL derive `normalized_identifier` from `identifier` through
`Units::NormalizeIdentifier` using canonical whitespace/separator, Unicode and
case-insensitive normalization.

#### Scenario: Identifier is normalized before persistence

- **WHEN** an actor submits `  Torre A 101 `
- **THEN** the visible identifier is trimmed
- **AND** `normalized_identifier` stores the canonical comparison value

#### Scenario: Blank normalized identifier is rejected

- **WHEN** identifier normalizes to blank
- **THEN** creation or update is rejected with an identifier error

#### Scenario: Client-supplied normalized identifier is not trusted

- **WHEN** a client submits identifier I and an unrelated normalized value N
- **THEN** the system derives the normalized value from I
- **AND** N cannot bypass uniqueness

#### Scenario: Import-supplied normalized identifier is not trusted

- **WHEN** a bulk import row includes `normalized_identifier`
- **THEN** the system ignores the imported normalized value
- **AND** derives `normalized_identifier` from the submitted visible identifier

#### Scenario: Search uses canonical normalization

- **WHEN** a user searches an identifier using equivalent case, whitespace or Unicode
- **THEN** the authorized unit can be found through the canonical normalized value

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

### Requirement: Units without section have a unique property-level context

The system MUST treat `property_section_id = NULL` as one logical uniqueness
context per organization and residential property.

#### Scenario: Duplicate identifier without section is rejected

- **GIVEN** P has a non-deleted unit `101` without section
- **WHEN** another unit `101` is created without section in P
- **THEN** creation is rejected

#### Scenario: Sectioned and unsectioned identifier may coexist

- **GIVEN** P has unit `101` without section
- **WHEN** eligible section S receives unit `101`
- **THEN** creation succeeds because the placement contexts differ

#### Scenario: Database protects null-section concurrency

- **GIVEN** concurrent requests create equivalent identifiers without section
- **WHEN** both commit in P
- **THEN** the database preserves at most one non-deleted unit
- **AND** the conflict becomes a domain validation error

### Requirement: Business status does not release identifier uniqueness

The system SHALL reserve the identifier context for every unit whose
`deleted_at` is null, regardless of business status.

#### Scenario: Inactive unit still blocks duplicate

- **GIVEN** U has status `inactive`
- **WHEN** another unit uses U's placement and normalized identifier
- **THEN** the duplicate is rejected

#### Scenario: Maintenance unit still blocks duplicate

- **GIVEN** U has status `maintenance`
- **WHEN** another unit uses U's placement and normalized identifier
- **THEN** the duplicate is rejected

#### Scenario: Archived unit still blocks duplicate

- **GIVEN** U has status `archived` and is not soft-deleted
- **WHEN** another unit uses U's placement and normalized identifier
- **THEN** the duplicate is rejected

### Requirement: Unit has controlled type

The system SHALL use `apartment`, `house`, `office`, `commercial_unit`,
`parking_space`, `storage_room`, `common_area`, and `other` as the canonical
unit-type catalog for new records.

#### Scenario: Canonical unit type is accepted

- **WHEN** a new unit uses a canonical unit type
- **THEN** the type may be persisted

#### Scenario: Unknown unit type is rejected

- **WHEN** a new unit uses a type outside the canonical catalog
- **THEN** creation is rejected

#### Scenario: Legacy type is not silently remapped

- **GIVEN** existing data uses a legacy unit type
- **WHEN** the foundation migration is prepared
- **THEN** an explicit audited mapping is required
- **AND** data is not renamed arbitrarily

### Requirement: Unit has controlled status

The system SHALL restrict status to `available`, `occupied`, `inactive`,
`maintenance`, or `archived`, with `available` as the ordinary creation default.

#### Scenario: New unit defaults to available

- **WHEN** an authorized actor creates a valid unit
- **THEN** status is `available`

#### Scenario: Invalid status is rejected

- **WHEN** an unknown status is submitted
- **THEN** creation or update is rejected

#### Scenario: Occupied status is not inferred by this change

- **WHEN** ownership or occupancy relationships change
- **THEN** this change does not silently rewrite unit status
- **AND** synchronization remains an explicit future decision

### Requirement: Unit update cannot bypass lifecycle operations

The system SHALL prevent generic descriptive updates from changing immutable
placement fields or executing lifecycle operations reserved for explicit
services.

#### Scenario: Update cannot change property or organization

* **GIVEN** unit U belongs to property P and organization O
* **WHEN** descriptive update submits another property or organization
* **THEN** the mutation is rejected or the untrusted values are ignored
* **AND** U remains in P and O

#### Scenario: Update cannot change section placement

* **GIVEN** unit U belongs to section A
* **WHEN** descriptive update submits section B
* **THEN** the update does not move U
* **AND** placement changes require `Units::MoveToSection`

#### Scenario: Update cannot archive unit

* **GIVEN** unit U is not archived
* **WHEN** descriptive update submits `status = archived`
* **THEN** the update is rejected
* **AND** archive requires `Units::Archive`

#### Scenario: Update can change operational status

* **WHEN** an authorized actor updates U from `available` to `inactive` or `maintenance`
* **THEN** the status change may be persisted according to the allowed status contract

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

### Requirement: Unit can move between section contexts safely

The system SHALL move a unit within its original property through
`Units::MoveToSection`.

#### Scenario: Unit moves to another valid section

- **GIVEN** U and sections A and B belong to P
- **WHEN** U is moved from A to eligible section B
- **THEN** `property_section_id` references B
- **AND** organization and property remain unchanged

#### Scenario: Unit moves to property-level context

- **GIVEN** U belongs to section A
- **WHEN** U is moved with no destination section
- **THEN** `property_section_id` becomes null
- **AND** property-level uniqueness is revalidated

#### Scenario: Move causing duplicate is rejected

- **GIVEN** destination context already contains an equivalent identifier
- **WHEN** U is moved there
- **THEN** the move is rejected
- **AND** U remains in its original placement

#### Scenario: Cross-property move is rejected

- **GIVEN** U belongs to P and section S belongs to Q
- **WHEN** S is submitted as destination
- **THEN** the move is rejected
- **AND** U remains in P

### Requirement: Unit can be archived non-destructively

The system SHALL archive a unit through `Units::Archive` without soft-deleting
it or destroying dependent records.

#### Scenario: Unit is archived

- **WHEN** an authorized actor archives U
- **THEN** U receives status `archived`
- **AND** `deleted_at` remains null

#### Scenario: Archive preserves relationships

- **GIVEN** U has ownerships, occupancies, leases or visits
- **WHEN** U is archived
- **THEN** those records remain persisted

#### Scenario: Archive is idempotent

- **GIVEN** U is already archived
- **WHEN** archive is requested again
- **THEN** the service returns a controlled no-op

#### Scenario: Archive does not release identifier

- **GIVEN** archived U is not soft-deleted
- **WHEN** another unit attempts to reuse its context and identifier
- **THEN** the duplicate is rejected

### Requirement: Soft-deleted unit can be restored safely

The system SHALL restore a soft-deleted unit through `Units::Restore` only when
its original tenant, property, section and uniqueness contract remain valid.

#### Scenario: Soft delete releases uniqueness context

- **GIVEN** U is soft-deleted
- **WHEN** another unit is created with U's former placement and identifier
- **THEN** creation may succeed

#### Scenario: Restore succeeds when context is free

- **GIVEN** U is soft-deleted
- **AND** no non-deleted unit occupies its context
- **WHEN** an authorized actor restores U
- **THEN** `deleted_at` is cleared
- **AND** its previous status is preserved

#### Scenario: Restore conflict is rejected

- **GIVEN** U is soft-deleted
- **AND** another unit reused its placement and identifier
- **WHEN** restore is attempted
- **THEN** restore is rejected with a controlled identifier conflict
- **AND** U remains soft-deleted

#### Scenario: Restore does not unarchive implicitly

- **GIVEN** U was archived before being soft-deleted
- **WHEN** U is restored
- **THEN** U remains `archived`

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

### Requirement: Unit authorization is property-scoped

The system SHALL evaluate `view_units` and `manage_units` against the concrete
residential property and SHALL deny cross-property or cross-organization access.

#### Scenario: Actor with view units can read unit catalog

* **GIVEN** actor A has `view_units` for property P
* **WHEN** A opens the unit catalog for P
* **THEN** units from P are visible according to the authorized scope

#### Scenario: Actor with view units but without manage units cannot mutate

* **GIVEN** actor A has `view_units` for property P
* **AND** A lacks `manage_units` for P
* **WHEN** A attempts to create, update, move, archive or restore a unit in P
* **THEN** authorization is denied
* **AND** no mutation occurs

#### Scenario: Tenant admin manages unit in own organization

- **GIVEN** A is tenant admin of O
- **AND** property P belongs to O
- **WHEN** A performs a unit operation permitted by `view_units` or `manage_units`
- **THEN** authorization succeeds within P

#### Scenario: Assigned property admin manages unit

- **GIVEN** A has an active and valid StaffAssignment to P
- **AND** the assignment grants `manage_units`
- **WHEN** A creates, updates, moves, archives or restores a unit in P
- **THEN** authorization succeeds

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
- **AND** mutation actions remain denied unless a future explicit capability grants them

#### Scenario: User without manage units cannot mutate

- **GIVEN** A lacks `manage_units` for P
- **WHEN** A attempts create, update, move, archive or restore
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

### Requirement: Unit metadata is non-authoritative

The system SHALL allow `metadata` for extensible non-critical attributes, but
SHALL NOT use it as the source of truth for tenant, property, section,
identifier, uniqueness, lifecycle or authorization.

#### Scenario: Metadata cannot override structural fields

* **WHEN** metadata contains property, section, identifier, type or status values
* **THEN** those values do not override the dedicated Unit columns

#### Scenario: Metadata cannot grant authorization

* **WHEN** metadata contains role, capability or access information
* **THEN** authorization ignores metadata
* **AND** access is resolved through the authorization contract

### Requirement: Unit mutations respect property lifecycle

The system SHALL reject ordinary unit mutations when the residential property
lifecycle does not allow catalog changes.

#### Scenario: Archived property rejects ordinary unit mutation

- **GIVEN** property P is archived
- **WHEN** create, update, move or archive is attempted for a unit in P
- **THEN** the mutation is denied according to property lifecycle rules