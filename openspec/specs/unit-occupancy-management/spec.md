# Unit Occupancy Management

## Purpose

Allow tenant admins to manage unit occupant/resident relationships (`UnitOccupancy`): view paginated occupants, add occupants by linking or creating people, update occupancy type and visit-authorization permissions, activate/deactivate occupants, soft-delete occupancies, and audit changes within organization boundaries — separate from legal ownership (`UnitOwnership`).

## Requirements

### Requirement: Admin views paginated unit occupants

The system SHALL display unit occupants on the unit management page in a dedicated **Residents / Occupants** section, visually separate from the **Owners** section, ordered with active occupancies first, then by start date descending, with server-side pagination.

#### Scenario: Occupants list with pagination

- **WHEN** an authorized admin opens the unit occupants tab
- **THEN** the system displays occupancy rows for that unit with columns: name, document, occupancy type, can authorize visits, start date, end date, status, and row actions
- **AND** pagination controls reflect total count from the server

#### Scenario: Active occupants appear before inactive

- **WHEN** a unit has both active and inactive occupancies
- **THEN** active occupancies appear before inactive occupancies in the list

### Requirement: Occupants section is separate from owners

The system SHALL NOT mix `UnitOwnership` and `UnitOccupancy` records in the same table or panel.

#### Scenario: Owners and occupants in separate UI sections

- **WHEN** admin views the unit detail page
- **THEN** legal owners appear only in the Owners section
- **AND** residents/occupants appear only in the Residents / Occupants section

#### Scenario: Legal owner is not auto-created as occupant

- **WHEN** admin adds a legal owner via `UnitOwnership`
- **THEN** the system does NOT automatically create a `UnitOccupancy` for that person
- **AND** the person appears in the occupants section only if an occupancy is explicitly created

### Requirement: Admin can open add-occupant drawer

The system SHALL provide an **Add occupant** action on the unit occupants panel that opens a multi-step drawer scoped to the current unit.

#### Scenario: Drawer shows unit context

- **WHEN** admin clicks **Add occupant**
- **THEN** a drawer opens showing the unit breadcrumb (property, sections, unit identifier)
- **AND** step 1 offers choosing between searching an existing person or creating a new one

#### Scenario: Drawer footer layout

- **WHEN** any step of the add-occupant drawer is displayed
- **THEN** the drawer footer uses layout `flex justify-between`
- **AND** the secondary action button is aligned to the left
- **AND** the primary action button is aligned to the right
- **AND** buttons are NOT centered at the bottom

### Requirement: Admin can add occupant by linking existing person

The system SHALL allow an admin to search people in the current organization and assign them as an occupant of the unit with occupancy type, visit-authorization flag, and validity dates.

#### Scenario: Search only current organization people

- **WHEN** admin searches for an existing person in the add-occupant flow
- **THEN** the system only returns people belonging to the current organization

#### Scenario: Successful link of existing person

- **WHEN** admin selects an existing person, sets occupancy type, `can_authorize_visits`, and start date (and optional end date)
- **AND** confirms the assignment
- **THEN** the system creates an active `UnitOccupancy` for that unit and person
- **AND** redirects or reloads the unit show page with the new occupant in the list

#### Scenario: Confirm step shows summary before create

- **WHEN** admin completes the assign step
- **THEN** the system shows a confirmation step summarizing person, occupancy type, visit authorization, and dates
- **AND** admin must confirm before the occupancy is persisted

### Requirement: Admin can add occupant by creating new person

The system SHALL allow creating a minimal person record and an occupancy in a single atomic transaction when no suitable existing person is found.

#### Scenario: Create person with minimum fields

- **WHEN** admin chooses to create a new person in the add-occupant flow
- **THEN** the system presents fields for at least full name (or first/last name), document number, and email
- **AND** upon successful submit creates both `Person` and `UnitOccupancy`

#### Scenario: Prevent duplicate person on create

- **WHEN** admin attempts to create a person whose normalized email or `document_number_digest` matches an existing person in the organization
- **THEN** the system rejects the operation with a clear error indicating the existing match
- **AND** no duplicate person or occupancy is created

### Requirement: Occupancy types are constrained

The system SHALL restrict `occupancy_type` to: `owner_resident`, `tenant`, `family_member`, `temporary_resident`, `authorized_manager`, `other`.

#### Scenario: Valid occupancy type accepted

- **WHEN** admin assigns occupancy type `tenant` to a person on a unit
- **THEN** the occupancy is saved with `occupancy_type` = `tenant`

#### Scenario: Invalid occupancy type rejected

- **WHEN** admin submits an occupancy with an unknown `occupancy_type`
- **THEN** the system rejects the operation with a validation error

### Requirement: Only one active occupancy per person and unit

The system SHALL NOT allow more than one active `UnitOccupancy` for the same person and unit within an organization.

#### Scenario: Duplicate active occupancy rejected

- **WHEN** admin attempts to create an active occupancy for a person who already has an active occupancy on the same unit
- **THEN** the system rejects the operation with a validation error
- **AND** no second active occupancy is created

#### Scenario: Person may occupy multiple units

- **WHEN** a person has an active occupancy on unit A
- **THEN** admin may create an active occupancy for the same person on unit B

#### Scenario: Unit may have multiple active occupants

- **WHEN** a unit already has one active occupant
- **THEN** admin may add another active occupant for a different person on the same unit

### Requirement: Visit authorization rules on occupancies

The system SHALL enforce that only occupants who are active AND have `can_authorize_visits = true` are eligible to authorize visits (domain rule; visit flow integration may follow in a later change).

#### Scenario: Inactive occupant cannot authorize visits

- **WHEN** an occupancy has `status` inactive
- **THEN** that occupant SHALL NOT be considered an active visit authorizer regardless of `can_authorize_visits`

#### Scenario: Active occupant without permission cannot authorize visits

- **WHEN** an occupancy has `status` active and `can_authorize_visits` false
- **THEN** that occupant SHALL NOT be considered an active visit authorizer

#### Scenario: Active occupant with permission can authorize visits

- **WHEN** an occupancy has `status` active, `can_authorize_visits` true, `starts_at` on or before today, and `ends_at` is blank or on or after today
- **THEN** that occupant SHALL be included in the set of active visit authorizers for the unit

### Requirement: Admin can edit occupancy

The system SHALL allow editing occupancy type, `can_authorize_visits`, start date, end date, and active/inactive status for an existing occupancy.

#### Scenario: Update occupancy type and visit permission

- **WHEN** admin edits an occupancy and changes type to `family_member` and sets `can_authorize_visits` to true
- **THEN** the system persists the changes
- **AND** the occupants list reflects the updated values

#### Scenario: Toggle active/inactive status

- **WHEN** admin deactivates an active occupancy
- **THEN** the occupancy `status` becomes inactive
- **AND** the occupant no longer counts as an active visit authorizer

- **WHEN** admin reactivates an inactive occupancy and no other active occupancy exists for the same person and unit
- **THEN** the occupancy `status` becomes active

#### Scenario: Reactivate blocked when duplicate active exists

- **WHEN** admin attempts to reactivate an occupancy while another active occupancy for the same person and unit exists
- **THEN** the system rejects the operation with a validation error

### Requirement: Admin can remove occupant via soft delete

The system SHALL remove an occupant from the active list using soft delete (logical deletion), preserving the record for history and audit.

#### Scenario: Soft delete occupancy

- **WHEN** admin confirms removal of an occupant
- **THEN** the system soft-deletes the `UnitOccupancy` record (sets `deleted_at`)
- **AND** the occupant no longer appears in the default active occupants list
- **AND** the database row is NOT physically deleted

#### Scenario: Soft-deleted occupancy excluded from active authorizers

- **WHEN** an occupancy is soft-deleted
- **THEN** it SHALL NOT be considered an active visit authorizer

### Requirement: Occupancy dates must be coherent

The system SHALL validate that `ends_at` is on or after `starts_at` when `ends_at` is present.

#### Scenario: End before start rejected

- **WHEN** admin sets `ends_at` earlier than `starts_at`
- **THEN** the system rejects the operation with a validation error on dates

#### Scenario: Open-ended occupancy allowed

- **WHEN** admin sets only `starts_at` and leaves `ends_at` blank
- **THEN** the occupancy is saved as open-ended

### Requirement: Occupancy mutations are authorized

The system SHALL enforce capability-based Pundit authorization for create, update, and destroy actions on `UnitOccupancy`, requiring `manage_occupancies` scoped to the unit's residential property, with organization isolation on every action.

#### Scenario: Tenant admin can mutate occupancies

- **WHEN** a user with `tenant_admin` role attempts to create an occupancy
- **THEN** the action is authorized

#### Scenario: Property admin can mutate occupancies for assigned property

- **WHEN** a user with active `property_admin` assignment on property P attempts to update an occupancy for a unit in P
- **THEN** the action is authorized

#### Scenario: Property admin denied for unassigned property

- **WHEN** a user with `property_admin` assignment only on property P attempts to mutate an occupancy for a unit in property Q
- **THEN** the system denies the action

#### Scenario: Concierge cannot mutate occupancies

- **WHEN** a user with only concierge assignment attempts to create or update an occupancy
- **THEN** the system denies the action

#### Scenario: Cross-organization access denied

- **WHEN** a user from organization A attempts to mutate an occupancy belonging to organization B
- **THEN** the system denies the action

### Requirement: Occupancy changes are audited

The system SHALL record audit entries for `UnitOccupancy` create, update, and soft-delete events, associated with the unit, and surface them in the unit change history where applicable.

#### Scenario: Create occupancy generates audit

- **WHEN** admin successfully creates an occupancy
- **THEN** an audit record is created for the new `UnitOccupancy`

#### Scenario: Update occupancy generates audit

- **WHEN** admin updates occupancy type or visit authorization
- **THEN** an audit record captures the changed attributes

#### Scenario: Soft delete generates audit

- **WHEN** admin soft-deletes an occupancy
- **THEN** an audit record reflects the deletion event

### Requirement: Occupancy UI reuses owner-flow patterns where appropriate

The system SHALL reuse visual and interaction patterns from the unit owner management flow (person search, person create fields, drawer stepper, Inertia error handling) for consistency, without conflating ownership and occupancy business rules.

#### Scenario: Person search matches owner drawer behavior

- **WHEN** admin uses person search in the add-occupant drawer
- **THEN** search UX (pagination, selection, empty states) follows the same patterns as the add-owner drawer

#### Scenario: Edit drawer footer layout

- **WHEN** admin opens the edit-occupancy drawer
- **THEN** the drawer footer uses the same `flex justify-between` layout as the add-occupant drawer

### Requirement: Warn when person already occupies another unit

The system SHALL warn admins when assigning a person who already has an active occupancy in another unit.

#### Scenario: Person has active occupancy in another unit

- **GIVEN** a person has an active occupancy in another unit
- **WHEN** an admin selects that person to create a new unit occupancy
- **THEN** the system shows a warning before confirmation
- **AND** the warning does not block creation
- **AND** the admin can continue and create the occupancy

## Out of Scope (this capability)

- Automatic synchronization between `UnitOwnership` and `UnitOccupancy`.
- Admin UI for `can_reserve_common_areas` or `can_withdraw_parcels`.
- Consolidation or migration of the `AuthorizedResident` model.
- Full visit approval workflow consuming occupant authorizers (only domain rules and query readiness).

