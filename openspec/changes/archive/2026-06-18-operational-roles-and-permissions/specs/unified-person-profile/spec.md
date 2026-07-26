## MODIFIED Requirements

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

## ADDED Requirements

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