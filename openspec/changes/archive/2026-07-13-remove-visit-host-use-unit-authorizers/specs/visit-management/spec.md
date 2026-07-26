## MODIFIED Requirements

### Requirement: Visit location and identities are tenant-consistent

The system SHALL persist each visit with organization, property, optional section, unit, and visitor person belonging to the same organization. Property and section SHALL be derived from the selected unit. The visit SHALL NOT require or store a host person.

#### Scenario: Coherent visit location is persisted

- **GIVEN** unit U belongs to property P and optional section S in organization O
- **WHEN** an authorized actor creates a visit for U
- **THEN** the visit stores O, P, S, and U consistently
- **AND** the visitor is a `Person` record in O

### Requirement: Authenticated action actors are Users

The system SHALL use `User` references for `created_by`, `authorized_by`, `checked_in_by`, `checked_out_by`, and functional history actors.

#### Scenario: Visit creation records authenticated user

- **GIVEN** an authorized user submits a valid visit
- **WHEN** creation succeeds
- **THEN** `created_by_id` references that `User`
- **AND** the visitor remains a `Person` reference

### Requirement: Full and restricted details are separated

The system SHALL provide full detail for `manage_visits` and restricted detail for `view_authorized_visits`.

#### Scenario: Admin receives full detail

- **GIVEN** a user has `manage_visits` for the visit
- **WHEN** detail is requested
- **THEN** the payload includes visit data, allowed person data, actors, functional history, notes, and allowed metadata

#### Scenario: Concierge receives restricted detail

- **GIVEN** a user has `view_authorized_visits` but not `manage_visits`
- **WHEN** operational detail is requested
- **THEN** the payload includes only visitor, unit, the unit's current authorizers, status, authorized time, entry/exit, operational actions, and minimal timeline
- **AND** full person profiles and administrative data are omitted

### Requirement: Operational and administrative serializers are distinct

The system SHALL provide operational list, admin list, full detail, restricted detail, operation summary, and functional event serializers.

#### Scenario: Operational list omits administrative fields

- **GIVEN** a concierge requests the operational list
- **WHEN** visits are serialized
- **THEN** only fields needed for access control, counters, and dropdown actions are returned

#### Scenario: Operation summary supports confirmation

- **GIVEN** check-in or check-out is allowed
- **WHEN** the confirmation surface opens
- **THEN** the summary includes visitor, unit, the unit's current authorizers, current status, relevant timestamps, and allowed actions

### Requirement: Visit creation includes a live authorization summary

The system SHALL provide the administrative visit form with dependent property/unit fields, visitor data, schedule, optional vehicle, notes, and `VisitAuthorizationSummary`.

#### Scenario: Summary mirrors form without persisting

- **GIVEN** an admin is filling the visit form
- **WHEN** fields change
- **THEN** the summary updates property, unit, visitor, reason, schedule, optional vehicle, and informational status
- **AND** the summary does not persist data or determine final status

### Requirement: Admin visit location step uses searchable selects

The admin visit creation form SHALL use endpoint-backed searchable select controls for the step 1 property and unit fields. These controls SHALL preserve existing selection dependencies: selecting a property loads authorized units and changing a parent selection clears dependent selections.

The searchable selects SHALL display only tenant-scoped and authorized options returned by visit form endpoints. Each select SHALL use 20 options as the default page size, support lazy loading more options on scroll, and keep a default selected value visible in the input. The controls SHALL preserve current disabled, loading, empty, validation, clear, and contextual-lock behavior.

#### Scenario: Property select filters properties

- **GIVEN** an authorized admin opens `/admin/visits/new`
- **AND** multiple authorized properties are available
- **WHEN** the admin types into the property searchable select
- **THEN** the property options are searched by trimmed, case-insensitive, accent-insensitive property name
- **AND** no unauthorized or cross-organization property is shown

#### Scenario: Duplicate property names remain distinguishable

- **GIVEN** two authorized properties share the same name
- **AND** the endpoint returns secondary descriptive text for them
- **WHEN** the property searchable select renders those options
- **THEN** the options can display secondary text to help the admin distinguish them
- **AND** searching still matches property name

#### Scenario: Property select lazy loads more properties

- **GIVEN** an authorized admin opens `/admin/visits/new`
- **AND** more than 20 authorized properties exist
- **WHEN** the admin opens the property searchable select without filtering and scrolls near the end
- **THEN** the next authorized property page is loaded

#### Scenario: Selecting property loads units

- **GIVEN** an authorized admin is on step 1 of the admin visit creation form
- **WHEN** the admin selects property P from the searchable select
- **THEN** the form clears any previously selected unit
- **AND** the form loads authorized units for P through the existing unit-loading behavior

#### Scenario: Unit select searches property units

- **GIVEN** property P is selected
- **WHEN** the admin types into the unit searchable select
- **THEN** the unit options are searched by trimmed, case-insensitive, accent-insensitive unit name within property P
- **AND** no unit outside property P or outside the admin's authorization is shown

#### Scenario: Duplicate unit names remain distinguishable

- **GIVEN** two authorized units in property P share the same name
- **AND** the endpoint returns secondary descriptive text for them
- **WHEN** the unit searchable select renders those options
- **THEN** the options can display secondary text to help the admin distinguish them
- **AND** searching still matches unit name

#### Scenario: Unit select lazy loads more units

- **GIVEN** property P has more than 20 authorized units
- **WHEN** the admin opens the unit searchable select without filtering and scrolls near the end
- **THEN** the next authorized unit page for property P is loaded

#### Scenario: Selecting unit loads status preview

- **GIVEN** an authorized admin is on step 1 with property P selected
- **WHEN** the admin selects unit U from the searchable select
- **THEN** the form refreshes the initial status preview for U

#### Scenario: Single option is not auto-selected

- **GIVEN** a property or unit searchable select has exactly one available option
- **WHEN** the options are loaded
- **THEN** the form does not automatically select that option
- **AND** the user must explicitly select it

#### Scenario: Clearing parent selections clears dependent values

- **GIVEN** an authorized admin has selected property P and unit U
- **WHEN** the admin clears the property select
- **THEN** the form clears unit U
- **AND** the dependent status preview is cleared or reset

#### Scenario: Contextual creation keeps property and unit locked

- **GIVEN** the admin visit creation form is opened from an existing unit context
- **WHEN** step 1 renders
- **THEN** the property and unit searchable selects show the contextual values
- **AND** those controls remain locked according to the existing contextual create behavior

#### Scenario: Default values remain visible before their option page loads

- **GIVEN** the visit form opens with a contextual or restored property or unit value
- **WHEN** the corresponding searchable select renders before that value appears in the loaded option page
- **THEN** the selected value's label is still visible in the input
- **AND** the selected value is not cleared

## ADDED Requirements

### Requirement: Visit views display the unit's current authorizers instead of a single host

The system SHALL display, wherever a visit's "host" was previously shown, the unit's current list of active residents with `can_authorize_visits: true` ("authorizers"), computed live from `UnitOccupancy.active_authorizers_for(unit)` — not a value persisted on the visit itself.

#### Scenario: Admin visit detail shows current unit authorizers

- **GIVEN** unit U has one or more active residents with `can_authorize_visits: true`
- **WHEN** an admin views a visit for U
- **THEN** the detail payload includes the current list of U's authorizers (id and display name)

#### Scenario: Unit with no active authorizer shows an empty list, not an error

- **GIVEN** unit U has no active resident with `can_authorize_visits: true`
- **WHEN** a visit for U is serialized for admin or concierge views
- **THEN** the authorizers list is empty
- **AND** serialization does not fail

#### Scenario: Authorizers list reflects current occupancy, not a historical snapshot

- **GIVEN** a visit was created for unit U when resident A was its only authorizer
- **AND** resident A's authorization has since ended and resident B's has begun
- **WHEN** that visit is viewed today
- **THEN** the displayed authorizers list shows resident B, not resident A
