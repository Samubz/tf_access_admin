## MODIFIED Requirements

### Requirement: Occupancy mutations are authorized

The system SHALL enforce Pundit authorization for create, update, and destroy actions on `UnitOccupancy` using the `manage_occupancies` capability scoped to the unit's residential property and current organization. Organization Super Admins (`tenant_admin`) SHALL retain organization-wide access.

#### Scenario: Unauthorized user cannot mutate occupancies

- **WHEN** a user without `manage_occupancies` for the unit's property attempts to create, update, or destroy an occupancy
- **THEN** the system returns forbidden
- **AND** no data is mutated

#### Scenario: Property administrator can mutate occupancies in assigned property

- **WHEN** a property administrator has `manage_occupancies` for property P
- **AND** attempts to create an occupancy on a unit belonging to P
- **THEN** the system authorizes the action

#### Scenario: Property administrator denied on unassigned property

- **WHEN** a property administrator assigned only to property P
- **AND** attempts to mutate an occupancy on a unit belonging to property Q
- **THEN** the system returns forbidden
- **AND** no data is mutated

#### Scenario: Admin from another organization cannot mutate occupancies

- **WHEN** an admin from organization A attempts to mutate an occupancy belonging to organization B
- **THEN** the system returns forbidden
- **AND** no data is mutated

#### Scenario: Organization admin can mutate occupancies across organization

- **WHEN** an organization admin attempts to create, update, or destroy an occupancy for any unit within their organization
- **THEN** the system authorizes the action

#### Scenario: Person from another organization denied

- **WHEN** a user attempts to create an occupancy using a person from another organization
- **THEN** the system returns forbidden or validation error
- **AND** no occupancy record is created

#### Scenario: Concierge cannot mutate occupancies

- **WHEN** a concierge assigned to the unit's property attempts to create, update, or destroy an occupancy
- **THEN** the system returns forbidden
- **AND** no data is mutated

