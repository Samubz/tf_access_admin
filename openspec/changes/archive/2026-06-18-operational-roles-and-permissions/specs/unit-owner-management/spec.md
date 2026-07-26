## MODIFIED Requirements

### Requirement: Ownership operations enforce operational authorization

The system SHALL restrict all unit ownership management actions to users with the `manage_ownerships` capability for the residential property of the unit, within the same organization as the unit and person. Organization Super Admins (`tenant_admin`) SHALL retain organization-wide access.

#### Scenario: Unauthorized user denied

- **WHEN** a user without `manage_ownerships` for the unit's property attempts to create, update, or delete an ownership
- **THEN** the system returns forbidden
- **AND** no data is mutated

#### Scenario: Property administrator can manage ownerships in assigned property

- **WHEN** a property administrator has `manage_ownerships` for property P
- **AND** attempts to create an ownership on a unit belonging to P
- **THEN** the system authorizes the action

#### Scenario: Property administrator denied on unassigned property

- **WHEN** a property administrator assigned only to property P
- **AND** attempts to manage ownerships on a unit belonging to property Q
- **THEN** the system returns forbidden and does not mutate data

#### Scenario: Cross-organization access denied

- **WHEN** a user attempts to manage ownerships for a unit outside their tenant
- **THEN** the system returns not found or forbidden

#### Scenario: Organization admin can manage ownerships across organization

- **WHEN** an organization admin attempts to manage ownerships for any unit within their organization
- **THEN** the system authorizes the action

#### Scenario: Person from another organization denied

- **WHEN** a user attempts to create an ownership using a person from another organization
- **THEN** the system returns forbidden or validation error
- **AND** no ownership record is created