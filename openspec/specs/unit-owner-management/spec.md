# Unit Owner Management

## Purpose

Allow tenant admins to manage unit ownership relationships: view paginated owners, add owners by linking or creating people, update assignments, soft-delete ownerships, and audit changes within organization boundaries.

## Requirements

### Requirement: Admin views paginated unit owners

The system SHALL display unit owners on the unit management page ordered with active ownerships first, then by start date descending, with server-side pagination.

#### Scenario: Owners list with pagination

- **WHEN** an authorized admin opens the unit owners tab
- **THEN** the system displays ownership rows for that unit
- **AND** pagination controls reflect total count from the server

#### Scenario: Active owners appear before inactive

- **WHEN** a unit has both active and inactive ownerships
- **THEN** active ownerships appear before inactive ownerships in the list

### Requirement: Admin sees ownership metrics on unit page

The system SHALL show ownership summary metrics for the unit: active owner count, assigned percentage, available percentage, and historical/inactive count.

#### Scenario: Metrics reflect active ownerships

- **WHEN** a unit has active ownerships totaling 60% assignment
- **THEN** the metrics display 60% assigned and 40% available

#### Scenario: Metrics show zero available when fully assigned

- **WHEN** a unit has active ownerships totaling 100% assignment
- **THEN** the metrics display 100% assigned and 0% available

### Requirement: Admin cannot add owners when ownership capacity is full

The system SHALL NOT allow incorporating new active owners when the unit has no available ownership percentage (`available_percentage` is 0).

#### Scenario: Add owner blocked when available is zero

- **WHEN** a unit's active ownerships total 100% assignment and `available_percentage` is 0
- **THEN** the "Add owner" action is disabled or otherwise unavailable
- **AND** the admin cannot start the add-owner flow to incorporate a new owner

#### Scenario: Create rejected when available is zero

- **WHEN** admin attempts to create an active ownership for a unit with 0% available capacity
- **THEN** the system rejects the operation with a validation error
- **AND** no ownership record is created

### Requirement: Admin can open add-owner drawer

The system SHALL provide an "Add owner" action on the unit owners panel that opens a multi-step drawer scoped to the current unit, but only when the unit has available ownership capacity (`available_percentage` > 0).

#### Scenario: Drawer shows unit context

- **WHEN** admin clicks "Add owner"
- **THEN** a drawer opens showing the unit breadcrumb (property, sections, unit identifier)
- **AND** step 1 offers choosing between searching an existing person or creating a new one

### Requirement: Admin can add owner by linking existing person

The system SHALL allow an admin to search people in the current organization and assign them as an owner of the unit with ownership percentage and validity dates.

#### Scenario: Search only current organization people

- **WHEN** admin searches for an existing person
- **THEN** the system only returns people belonging to the current organization

#### Scenario: Successful link of existing person

- **WHEN** admin selects an existing person, sets ownership percentage and start date within available capacity
- **THEN** the system creates an active `UnitOwnership` for that unit and person
- **AND** redirects or reloads the unit show page with the new owner in the list

#### Scenario: Prevent concurrent percentage overflow

- **WHEN** two admins attempt to create or update ownership percentages for the same unit at the same time
- **THEN** the system serializes the operation by locking the unit
- **AND** only changes that keep active ownership percentage at or below 100% are persisted

#### Scenario: Reject when percentage exceeds available capacity

- **WHEN** admin assigns an active ownership percentage that would cause total active shares to exceed 100%
- **THEN** the system rejects the operation with a validation error
- **AND** no ownership record is created

#### Scenario: Reject duplicate active ownership for same person

- **WHEN** admin attempts to add an active ownership for a person who already has an active ownership on the same unit
- **THEN** the system rejects the operation with a validation error

### Requirement: Admin can add owner by creating new person

The system SHALL allow an admin to create a minimal person record in the current organization and assign them as unit owner in a single flow.

#### Scenario: Create person and ownership together

- **WHEN** admin completes the new-person form and assignment step with valid data
- **THEN** the system creates the `Person` and the `UnitOwnership` in one transaction
- **AND** the new owner appears on the unit owners list

#### Scenario: Reject duplicate person by document or email

- **WHEN** admin attempts to create a new person with a document or email that already exists in the current organization
- **THEN** the system rejects the creation
- **AND** suggests using the existing person instead
- **AND** no ownership record is created

#### Scenario: Roll back if ownership validation fails

- **WHEN** person data is valid but ownership assignment fails validation
- **THEN** neither person nor ownership is persisted

### Requirement: Admin can update an existing ownership

The system SHALL allow an admin to update ownership percentage, validity dates, and status of an existing ownership on a unit.

#### Scenario: Update ownership percentage

- **WHEN** admin edits an active ownership and changes percentage within available capacity
- **THEN** the system persists the change
- **AND** unit metrics and change history reflect the update

#### Scenario: Reject update when percentage exceeds capacity

- **WHEN** admin edits an ownership and the resulting active ownership percentage exceeds 100%
- **THEN** the system rejects the update
- **AND** no changes are persisted

#### Scenario: Reject invalid date range

- **WHEN** admin sets `ends_at` before `starts_at`
- **THEN** the system rejects the update with a validation error

### Requirement: Admin can soft-delete an ownership

The system SHALL allow an admin to remove an ownership from the active owners list using soft delete via `acts_as_paranoid`, without hard-deleting historical data.

#### Scenario: Soft-delete active ownership

- **WHEN** admin deletes an active ownership from the row actions menu
- **THEN** the ownership is soft-deleted using `acts_as_paranoid`
- **AND** it no longer counts toward active assignment percentage
- **AND** it remains available for audit/history purposes
- **AND** it is not hard-deleted from the database
- **AND** ownership metrics are recalculated immediately

### Requirement: Ownership changes are audited

The system SHALL record ownership create, update, and delete events in the tenant audit log and surface recent entries in the unit change history sidebar.

#### Scenario: Create generates audit entry

- **WHEN** an ownership is successfully created
- **THEN** an audit entry is recorded associated with the unit
- **AND** the unit change history sidebar includes a human-readable description

### Requirement: Ownership operations enforce operational authorization

The system SHALL restrict unit ownership management actions using capability-based authorization (`manage_ownerships`) scoped to the residential property of the unit, with organization isolation enforced on every action.

#### Scenario: Tenant admin can manage ownerships

- **WHEN** a user with `tenant_admin` role in the organization attempts to create an ownership
- **THEN** the action is authorized

#### Scenario: Property admin can manage ownerships for assigned property

- **WHEN** a user with active `property_admin` staff assignment on property P attempts to create an ownership for a unit in P
- **THEN** the action is authorized

#### Scenario: Property admin denied for unassigned property

- **WHEN** a user with `property_admin` assignment only on property P attempts to create an ownership for a unit in property Q
- **THEN** the system returns forbidden and does not mutate data

#### Scenario: Concierge cannot manage ownerships

- **WHEN** a user with only concierge assignment attempts to create an ownership
- **THEN** the system returns forbidden and does not mutate data

#### Scenario: Cross-organization access denied

- **WHEN** a user attempts to manage ownerships for a unit outside their organization
- **THEN** the system returns not found or forbidden

### Requirement: Ownership restoration is out of scope

The system SHALL NOT provide ownership restoration functionality in the admin interface.

#### Scenario: No restore action in admin UI

- **WHEN** an admin views a soft-deleted ownership
- **THEN** no restore or undelete action is available
### Requirement: Ownership relationship model

The system SHALL support many-to-many ownership relationships between people and units.

#### Scenario: Person owns multiple units

- WHEN a person is assigned to multiple units
- THEN all ownerships are persisted independently

#### Scenario: Unit has multiple owners

- WHEN multiple people are assigned to the same unit
- THEN the system maintains separate ownership records for each owner
