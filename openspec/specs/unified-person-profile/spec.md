# Unified Person Profile

## Purpose

Establish `Person` as the single identity entity per organization. Contextual roles are derived from domain relationships, not separate identity tables. Provide a unified admin profile screen to view all person contexts in one place. Deduplication by document digest and normalized email is consistent across all flows.

## Requirements

### Requirement: Person is the single identity entity per organization

The system SHALL treat `people` as the only identity store within an organization. The system MUST NOT introduce parallel identity tables such as `owners`, `visitors`, `staff_people`, or `residents`.

#### Scenario: Owner identity uses Person

- **WHEN** an admin assigns an owner to a unit
- **THEN** the system links a `UnitOwnership` to a `Person` record
- **AND** does not create a separate owner identity record

#### Scenario: Resident identity uses Person

- **WHEN** an admin assigns an occupant to a unit
- **THEN** the system links a `UnitOccupancy` to a `Person` record
- **AND** does not create a separate resident identity record

### Requirement: One person record per organization

The system SHALL allow at most one active identity record per person per organization, deduplicated by document and email.

#### Scenario: Document identifies unique person in organization

- **WHEN** two flows reference the same document number in the same organization
- **THEN** the system resolves to the same `Person` record
- **AND** does not create a duplicate

#### Scenario: Cross-organization isolation

- **WHEN** the same document exists in two different organizations
- **THEN** each organization has its own independent `Person` record

### Requirement: Organization membership for incorporated people

The system SHALL ensure `OrganizationMembership` exists for people created through admin and unit incorporate flows.

#### Scenario: New person gets membership

- **WHEN** a person is created through admin or unit flows
- **THEN** the system creates or activates organization membership for that person

### Requirement: Person type is not a contextual role

The system SHALL use `person_type` only for natural vs legal entity. The system MUST NOT use `person_type` to store owner, resident, visitor, or staff roles.

#### Scenario: Multiple contextual roles on same person

- **WHEN** a person has active ownership and active occupancy
- **THEN** the system represents both owner and resident contexts on the same `Person`

#### Scenario: Visitor and resident simultaneously

- **WHEN** a person has an active occupancy and a linked visitor profile or future visit participation
- **THEN** the system represents both resident and visitor contextual roles on the same `Person`

### Requirement: Contextual roles are derived from relationships

The system SHALL derive contextual roles from active domain relationships. Roles MUST NOT be stored as the primary identity attribute on `Person`. Derived roles MUST support at minimum: owner, resident, visitor, concierge, property_admin, cleaning_staff, internal_staff, and system_user. Staff contextual roles (`concierge`, `property_admin`, `cleaning_staff`) MUST be derived from active `StaffAssignment` records.

#### Scenario: Internal staff badge from active StaffAssignment

- **WHEN** a person has an active `StaffAssignment` mapped to `internal_staff`
- **THEN** derived contextual roles include `internal_staff`
- **AND** the unified profile displays a Personal interno badge

#### Scenario: Owner role from active ownership

- **WHEN** a person has at least one active `UnitOwnership`
- **THEN** derived contextual roles include `owner`
- **AND** the unified profile displays a Propietario badge

#### Scenario: Resident role from active occupancy

- **WHEN** a person has at least one active `UnitOccupancy`
- **THEN** derived contextual roles include `resident`
- **AND** the unified profile displays a Residente badge

#### Scenario: System user role from linked User

- **WHEN** a person has a non-null `user_id`
- **THEN** derived contextual roles include `system_user`
- **AND** the unified profile displays a Usuario badge

#### Scenario: Concierge badge from active StaffAssignment

- **WHEN** a person has an active `StaffAssignment` with `staff_type` `concierge`
- **THEN** derived contextual roles include `concierge`
- **AND** the unified profile displays a Conserje badge

#### Scenario: Property admin badge from manager StaffAssignment

- **WHEN** a person has an active `StaffAssignment` with `staff_type` `manager`
- **THEN** derived contextual roles include `property_admin`
- **AND** the unified profile displays an Administrador badge

#### Scenario: Cleaning staff badge from active StaffAssignment

- **WHEN** a person has an active `StaffAssignment` with `staff_type` `cleaning`
- **THEN** derived contextual roles include `cleaning_staff`

#### Scenario: Multiple badges displayed together

- **WHEN** a person qualifies for owner, resident, property_admin, and system_user simultaneously
- **THEN** the unified profile displays all corresponding badges

#### Scenario: Ended relationship removes derived role

- **WHEN** a person has no active `UnitOwnership` records
- **THEN** derived contextual roles do not include `owner`

#### Scenario: Expired staff assignment removes staff badge

- **WHEN** a person's `StaffAssignment` has ended or is outside its active date range
- **THEN** derived contextual roles do not include the corresponding staff role

### Requirement: Centralized deduplication by document and email

The system SHALL provide a shared resolver that finds an existing person in the current organization using: (1) `document_number_digest`, (2) normalized email via linked `User`, (3) normalized email in person metadata.

#### Scenario: Document match returns existing person

- **WHEN** a flow supplies a document matching an existing digest in the organization
- **THEN** the resolver returns that `Person`

#### Scenario: Email match via User returns existing person

- **WHEN** no document match exists and email matches a `User` linked to a person in the organization
- **THEN** the resolver returns that `Person`

#### Scenario: Email match via metadata returns existing person

- **WHEN** no document or User match exists and email matches person metadata in the organization
- **THEN** the resolver returns that `Person`

#### Scenario: Soft-deleted people excluded from resolution

- **WHEN** a soft-deleted person had a document number
- **THEN** the resolver does not return that person
- **AND** a new person may be created with the same document if no other active person holds it

### Requirement: Duplicate identity is rejected on create and update

The system SHALL reject creating or updating a `Person` when document or normalized email would duplicate another non-deleted person in the same organization.

#### Scenario: Duplicate document rejected

- **WHEN** a flow attempts to create a person with a document already used in the organization
- **THEN** the system rejects with a validation error referencing the existing person when available

#### Scenario: Duplicate email rejected

- **WHEN** a flow attempts to create a person with an email already used in the organization
- **THEN** the system rejects with a validation error

### Requirement: Optional Person and User association

The system SHALL allow a `Person` without a linked `User`. When linked, at most one `Person` per organization MAY reference the same `user_id`.

#### Scenario: Person without user is valid

- **WHEN** a person is created as owner or resident without system access
- **THEN** the person is saved with `user_id` null

#### Scenario: Duplicate user link rejected

- **WHEN** admin links a `user_id` already used by another person in the organization
- **THEN** the system rejects the operation

### Requirement: Ownership and occupancy flows use centralized resolver

The system SHALL use the centralized resolver in `UnitOwnerships::CreateWithPerson`, `UnitOccupancies::CreateWithPerson`, and bulk import person resolution.

#### Scenario: Add owner with duplicate document

- **WHEN** admin adds an owner with a document matching an existing person
- **THEN** the system applies centralized resolution rules and does not create a duplicate

#### Scenario: Add occupant with duplicate document

- **WHEN** admin adds an occupant with a document matching an existing person
- **THEN** the system applies centralized resolution rules and does not create a duplicate

### Requirement: Unified person profile page exists

The system SHALL provide an admin page **Perfil Unificado de Persona** at `GET /admin/people/:id` rendering all person contexts in a single view.

#### Scenario: Authorized admin opens unified profile

- **WHEN** an authorized admin navigates to a person's profile
- **THEN** the system renders the unified profile page for that person in the current organization

#### Scenario: Unauthorized access denied

- **WHEN** a user without permission requests a person profile
- **THEN** the system denies access

### Requirement: Profile header displays identity and role badges

The unified profile header SHALL display full name, document, email, phone, status, and calculated role badges.

#### Scenario: Header shows identity fields

- **WHEN** admin opens the unified profile
- **THEN** the header shows display name, document, email, phone, and person status

#### Scenario: Header shows calculated badges

- **WHEN** the person has derived contextual roles
- **THEN** the header displays a badge for each active contextual role

### Requirement: Profile provides tabbed navigation

The unified profile SHALL provide tabs: Resumen, Propiedades, Residencias, Staff, Visitas, and Historial using the same tab navigation pattern as unit management.

#### Scenario: Tabs are visible on profile load

- **WHEN** admin opens the unified profile
- **THEN** all six tabs are available in the tab navigation

#### Scenario: Tab selection switches content

- **WHEN** admin selects a tab
- **THEN** the profile displays content for that tab without leaving the page

### Requirement: Resumen tab shows personal summary

The Resumen tab SHALL display personal data, linked system user, calculated roles, and relevant dates.

#### Scenario: Resumen shows linked user

- **WHEN** the person has a linked `User`
- **THEN** the Resumen tab shows user name and email

#### Scenario: Resumen shows tenant access role separately

- **WHEN** the person has a Rolify tenant role
- **THEN** the Resumen tab shows tenant access role distinct from contextual domain badges

### Requirement: Propiedades tab lists all ownerships

The Propiedades tab SHALL list all `UnitOwnership` records for the person with columns: property, section, unit, ownership percentage, and status.

#### Scenario: Ownership row shows unit context

- **WHEN** the person owns a unit
- **THEN** the Propiedades tab shows property name, section name, unit identifier, percentage, and ownership status

#### Scenario: Multiple ownerships listed

- **WHEN** the person has multiple ownerships across units
- **THEN** the Propiedades tab lists all ownerships for that person in the organization

#### Scenario: Empty ownerships state

- **WHEN** the person has no ownerships
- **THEN** the Propiedades tab shows a consistent empty state

#### Scenario: Navigate to unit from ownership row

- WHEN admin clicks a unit in the Propiedades tab
- THEN the system navigates to the corresponding unit page

#### Scenario: Navigate to property from ownership row

- WHEN admin clicks a property in the Propiedades tab
- THEN the system navigates to the corresponding property page

### Requirement: Residencias tab lists all occupancies

The Residencias tab SHALL list all `UnitOccupancy` records for the person with columns: property, section, unit, occupancy type, and status.

#### Scenario: Occupancy row shows unit context

- **WHEN** the person occupies a unit
- **THEN** the Residencias tab shows property name, section name, unit identifier, occupancy type, and occupancy status

#### Scenario: Multiple occupancies listed

- **WHEN** the person has multiple occupancies
- **THEN** the Residencias tab lists all occupancies for that person in the organization

#### Scenario: Empty occupancies state

- **WHEN** the person has no occupancies
- **THEN** the Residencias tab shows a consistent empty state

### Requirement: Staff tab is prepared for future property assignments

The Staff tab SHALL display the structure for properties where the person works, with columns for property, role, and status. When no staff assignments exist, the system SHALL show a prepared empty state.

#### Scenario: Staff tab shows empty state initially

- **WHEN** the person has no staff assignments
- **THEN** the Staff tab renders with defined columns and an empty state message
- **AND** does not error

#### Scenario: Staff tab ready for future data

- **WHEN** staff assignments are added in a future change
- **THEN** the Staff tab structure supports listing multiple property work assignments per person

### Requirement: Visitas tab is prepared for future visit history

The Visitas tab SHALL provide structure for future visit history associated with the person. When no visits exist, the system SHALL show a prepared empty state.

#### Scenario: Visitas tab shows empty state initially

- **WHEN** the person has no visit records
- **THEN** the Visitas tab renders with a prepared empty state
- **AND** does not error

### Requirement: Historial tab shows person-related audit history

The Historial tab SHALL display relevant audit entries for the person and associated ownership and occupancy changes.

#### Scenario: Person audit entries visible

- **WHEN** the person record was created or updated with auditing enabled
- **THEN** the Historial tab includes those audit entries

#### Scenario: Related ownership and occupancy audits visible

- **WHEN** ownerships or occupancies linked to the person were audited
- **THEN** the Historial tab includes those related audit entries

#### Scenario: History ordered by most recent first

- WHEN the Historial tab is displayed
- THEN entries are ordered descending by event date

### Requirement: Navigation to unified profile from entry points

The system SHALL link to the unified person profile from the people list, unit owners table, and unit occupants table.

#### Scenario: Navigate from people list

- **WHEN** admin selects a person from the people index
- **THEN** the system navigates to the unified person profile

#### Scenario: Navigate from unit owners table

- **WHEN** admin clicks a person name in the unit owners table
- **THEN** the system navigates to that person's unified profile

#### Scenario: Navigate from unit occupants table

- **WHEN** admin clicks a person name in the unit occupants table
- **THEN** the system navigates to that person's unified profile

### Requirement: Profile UX follows existing admin patterns

The unified profile UI SHALL use Shadcn Vue components, Inertia, reusable data tables, consistent empty states, and patterns aligned with Property Sections, Unit Owners, and Unit Occupancies modules.

#### Scenario: Tables reuse admin table components

- **WHEN** Propiedades or Residencias tabs render data
- **THEN** the UI uses the same reusable admin table components as unit management modules

#### Scenario: Empty states match existing modules

- **WHEN** a tab has no records
- **THEN** the empty state follows the same visual and copy patterns as unit owners and occupancies empty states

### Requirement: Existing data remains valid without migration

The system SHALL preserve all existing `Person`, `UnitOwnership`, and `UnitOccupancy` records without requiring a data migration.

#### Scenario: Existing ownerships appear in profile

- **WHEN** admin opens the profile of a person with existing ownerships
- **THEN** those ownerships appear in the Propiedades tab

#### Scenario: Existing occupancies appear in profile

- **WHEN** admin opens the profile of a person with existing occupancies
- **THEN** those occupancies appear in the Residencias tab

### Requirement: Future visitor and staff domains use Person identity

The system SHALL require future visitor and staff flows to reference `person_id` on `Person` rather than separate identity tables.

#### Scenario: Visitor profile links to Person

- **WHEN** a visitor profile represents a canonical identity
- **THEN** it links to a `Person` in the same organization via `person_id`

#### Scenario: Future staff references Person

- **WHEN** property staff assignments are introduced
- **THEN** assignments reference `person_id` without a separate staff identity table

### Requirement: Profile summary metrics are displayed

The unified profile SHALL display summary metrics for the person's participation across the system.

#### Scenario: Summary metrics visible

- WHEN admin opens the unified profile
- THEN the profile displays active ownership count
- AND active occupancy count
- AND visit count when available
- AND staff assignment count when available

### Requirement: Profile access respects operational capabilities

The system SHALL determine unified profile access and edit permissions using operational capabilities from `Authorization::Resolver`, not only organization admin role.

#### Scenario: Property admin views person in property scope

- **WHEN** a property administrator has `view_people` for a property where the profile person has an active ownership, occupancy, or staff assignment
- **THEN** the system renders the unified profile

#### Scenario: Property admin denied outside assigned property scope

- **WHEN** a property administrator requests the profile of a person related only to another property
- **THEN** the system denies access

#### Scenario: User without view_people denied

- **WHEN** a user without `view_people` for any property context of the profile person requests the profile
- **THEN** the system denies access

#### Scenario: Profile permissions prop reflects capabilities

- **WHEN** the unified profile is rendered
- **THEN** the `permissions` prop indicates whether edit and administrative actions are allowed based on `manage_people` and related capabilities

### Requirement: Staff tab lists active StaffAssignment data

The Staff tab SHALL list active `StaffAssignment` records for the person with columns for property, staff type (role), and status.

#### Scenario: Staff tab shows assignments

- **WHEN** the person has active staff assignments
- **THEN** the Staff tab displays one row per assignment with property name, staff type, and status

#### Scenario: Staff tab shows empty state when no assignments

- **WHEN** the person has no staff assignments
- **THEN** the Staff tab renders with defined columns and an empty state message
- **AND** does not error

#### Scenario: Property admin badge from mapped StaffAssignment

- **WHEN** a person has an active `StaffAssignment` with `staff_type` mapped to `property_admin`
- **THEN** derived contextual roles include `property_admin`
- **AND** the unified profile displays an Administrador de propiedad badge

#### Scenario: Staff assignment from another organization is ignored

- **WHEN** a person has a `StaffAssignment` associated with a residential property from another organization
- **THEN** derived contextual roles for the current organization do not include that staff role

#### Scenario: Concierge cannot access full unified profile by default

- **WHEN** a concierge assigned to a property requests the full unified profile of a person related to that property
- **THEN** the system denies access unless an explicit `view_people` capability is granted

#### Scenario: User can view own linked person profile

- **WHEN** a user requests the unified profile of their linked `Person`
- **THEN** the system renders the profile with self-service permissions only
