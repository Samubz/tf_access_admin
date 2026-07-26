# Visit Management

## Purpose

Enable visit creation and administration, plus operational check-in/check-out, within strict organization, property, unit, state, and capability boundaries. Visitors are canonical `Person` records; authenticated actors are `User` records.

## Requirements

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

### Requirement: Backend resolves initial visit status

The system SHALL determine initial status from backend authorization and SHALL NOT trust a client-supplied status without validating capability and scope.

#### Scenario: Authorized administrator creates an authorized visit

- **GIVEN** an actor has `manage_visits` and authority to authorize in the selected scope
- **WHEN** the actor creates a valid visit requesting immediate authorization
- **THEN** the visit is created as `authorized`
- **AND** `authorized_by_id` records the actor

#### Scenario: Creator without direct authorization creates pending visit

- **GIVEN** an actor has `create_visits` but not `authorize_visits` or applicable `manage_visits`
- **WHEN** the actor creates a valid visit
- **THEN** the backend creates it as `pending`
- **AND** ignores any unauthorized request for `authorized`

### Requirement: MVP status transitions are enforced

The system SHALL permit only `pending -> authorized`, `pending -> cancelled`, `authorized -> checked_in`, `authorized -> cancelled`, and `checked_in -> checked_out`.

#### Scenario: Pending visit is authorized

- **GIVEN** a visit is `pending`
- **WHEN** an actor allowed by `authorize?` authorizes it
- **THEN** it becomes `authorized`

#### Scenario: Authorized visit is checked in

- **GIVEN** a visit is `authorized` and inside its validity window
- **WHEN** an actor allowed by `check_in?` confirms entry
- **THEN** it becomes `checked_in`

#### Scenario: Checked-in visit is checked out

- **GIVEN** a visit is `checked_in`
- **WHEN** an actor allowed by `check_out?` confirms exit
- **THEN** it becomes `checked_out`

#### Scenario: Pending or authorized visit is cancelled

- **GIVEN** a visit is `pending` or `authorized`
- **WHEN** an actor allowed by `cancel?` cancels it
- **THEN** it becomes `cancelled`

### Requirement: Invalid transitions do not mutate visits

The system MUST reject check-in from any state other than `authorized`, check-out from any state other than `checked_in`, and cancellation from `checked_in`, `checked_out`, or `cancelled`.

#### Scenario: Pending visit cannot check in

- **GIVEN** a visit is `pending`
- **WHEN** any actor attempts check-in
- **THEN** the transition is rejected
- **AND** status remains `pending`

#### Scenario: Authorized visit cannot check out directly

- **GIVEN** a visit is `authorized`
- **WHEN** any actor attempts check-out
- **THEN** the transition is rejected
- **AND** status remains `authorized`

#### Scenario: Checked-in visit cannot be cancelled

- **GIVEN** a visit is `checked_in`
- **WHEN** an actor attempts cancellation
- **THEN** the transition is rejected
- **AND** status remains `checked_in`

### Requirement: Functional history is distinct from technical audit

The system SHALL maintain user-visible functional history independently from `audited`. Each event SHALL include visit, organization, event type, from/to status, actor user, occurrence time, notes, and metadata.

#### Scenario: Creation event is recorded

- **GIVEN** a visit is successfully created
- **WHEN** the creation transaction commits
- **THEN** a `created` functional event is persisted
- **AND** it includes `actor_user_id`, `occurred_at`, organization, and resulting status

#### Scenario: Every MVP transition records an event

- **GIVEN** an authorize, check-in, check-out, or cancel transition succeeds
- **WHEN** the transaction commits
- **THEN** an `authorized`, `checked_in`, `checked_out`, or `cancelled` event is persisted
- **AND** it records from/to status and actor

#### Scenario: Timeline uses functional history

- **GIVEN** a user opens visit detail
- **WHEN** history is serialized
- **THEN** the timeline and actor panel are built from functional events
- **AND** technical audit records are not required as the user-facing timeline

### Requirement: Check-in persists operational metadata

The system SHALL allow check-in metadata for access point, access type, optional vehicle plate, and notes.

#### Scenario: Concierge checks in with metadata

- **GIVEN** a visit is `authorized` in the concierge's assigned property
- **WHEN** the concierge confirms check-in with operational fields
- **THEN** `Visits::CheckIn` persists actor and timestamp
- **AND** stores allowed operational metadata
- **AND** records a `checked_in` functional event with that metadata

### Requirement: Check-out persists operational metadata

The system SHALL allow check-out metadata for access point, optional incident type, and notes.

#### Scenario: Concierge checks out with metadata

- **GIVEN** a visit is `checked_in` in the concierge's assigned property
- **WHEN** the concierge confirms check-out with operational fields
- **THEN** `Visits::CheckOut` persists actor and timestamp
- **AND** stores allowed operational metadata
- **AND** records a `checked_out` functional event with that metadata

### Requirement: Concierge sees only operational visits in assigned properties

The system SHALL scope concierge listings to assigned properties and statuses `authorized`, `checked_in`, and recent `checked_out`.

#### Scenario: Concierge lists assigned-property operational visits

- **GIVEN** a concierge has active assignment on property P
- **WHEN** the concierge opens the operational list
- **THEN** only operational visits for P are returned
- **AND** visits from other properties are excluded

#### Scenario: Concierge does not see pending or cancelled visits

- **GIVEN** property P has pending, cancelled, authorized, checked-in, and recent checked-out visits
- **WHEN** its concierge lists visits
- **THEN** pending and cancelled visits are excluded
- **AND** authorized, checked-in, and recent checked-out visits may be included

### Requirement: Concierge cannot administer visits

The system MUST deny concierge creation, update, authorization, and cancellation in the MVP.

#### Scenario: Concierge cannot create visit

- **GIVEN** a user only has concierge operational capabilities
- **WHEN** the user attempts to create a visit
- **THEN** `create?` denies the action
- **AND** no visit is persisted

#### Scenario: Concierge cannot edit authorize or cancel

- **GIVEN** a concierge can view an operational visit
- **WHEN** the concierge attempts update, authorize, or cancel
- **THEN** the corresponding policy action denies it
- **AND** the visit is unchanged

### Requirement: Concierge checks in only authorized visits

The system SHALL allow check-in only with `register_visit_entry`, matching property scope, `authorized` status, and a valid time window.

#### Scenario: Assigned concierge checks in authorized visit

- **GIVEN** a concierge has `register_visit_entry` for property P
- **AND** a visit in P is `authorized` and temporally valid
- **WHEN** check-in is requested
- **THEN** policy and transition permit the action

#### Scenario: Concierge cannot check in another property's visit

- **GIVEN** a concierge is assigned only to P
- **WHEN** check-in is requested for property Q
- **THEN** authorization denies the action

### Requirement: Concierge checks out only checked-in visits

The system SHALL allow check-out only with `register_visit_exit`, matching property scope, and `checked_in` status.

#### Scenario: Assigned concierge checks out checked-in visit

- **GIVEN** a concierge has `register_visit_exit` for property P
- **AND** a visit in P is `checked_in`
- **WHEN** check-out is requested
- **THEN** policy and transition permit the action

### Requirement: Administrative visit scope follows organization and property assignments

The system SHALL expose all organization visits to tenant admins and only assigned-property visits to property admins.

#### Scenario: Tenant admin lists organization visits

- **GIVEN** a tenant admin belongs to organization O
- **WHEN** visit management is opened
- **THEN** the scope contains visits in O
- **AND** no visit from another organization is returned

#### Scenario: Property admin lists assigned properties only

- **GIVEN** a property admin is assigned to P but not Q
- **WHEN** visit management is opened
- **THEN** visits from P may be returned
- **AND** visits from Q are excluded

### Requirement: Administrative users manage visits according to capability and state

The system SHALL allow administrative creation, update, authorization, and cancellation only when policy, scope, and state permit.

#### Scenario: Admin creates visit in scope

- **GIVEN** an admin has `manage_visits` for property P
- **WHEN** a valid visit is submitted for a unit in P
- **THEN** creation succeeds
- **AND** property and section are derived from the unit

#### Scenario: Admin cancels pending or authorized visit

- **GIVEN** an admin has `manage_visits` for a visit in scope
- **AND** the visit is `pending` or `authorized`
- **WHEN** cancellation is requested
- **THEN** the visit becomes `cancelled`

#### Scenario: Admin without operational capability cannot check in

- **GIVEN** an admin has `manage_visits` but not `register_visit_entry`
- **WHEN** check-in is requested
- **THEN** authorization denies the action

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

### Requirement: Backend exposes allowed actions per visit

The system SHALL serialize `permissions` and/or `actions` per visit from policy, state, scope, and transition rules.

#### Scenario: Authorized visit exposes check-in to eligible concierge

- **GIVEN** a concierge may check in an authorized visit
- **WHEN** the visit is serialized
- **THEN** `permissions.check_in` is true
- **AND** edit, authorize, and cancel are false

#### Scenario: Frontend does not infer unavailable action

- **GIVEN** the backend returns an action as false or absent
- **WHEN** the row or detail is rendered
- **THEN** that action is not exposed
- **AND** state alone does not make it visible

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

### Requirement: Concierge Authorized Visits provides operational workflow

The system SHALL provide assigned property context, tabs for authorized/checked-in/recent checked-out, search, filters, pagination, and dropdown actions.

#### Scenario: Row actions are state-specific and backend-driven

- **GIVEN** operational rows are rendered
- **WHEN** the backend permits actions
- **THEN** authorized rows may expose view and check-in
- **AND** checked-in rows may expose view and check-out
- **AND** recent checked-out rows expose view

### Requirement: Admin Visits Management provides scoped management workflow

The system SHALL provide scope selection where applicable, filters, search, pagination, creation access, and dropdown actions.

#### Scenario: New visit button follows permission

- **GIVEN** a user opens admin visit management
- **WHEN** the backend grants creation
- **THEN** Nueva visita is visible
- **AND** it is hidden otherwise

#### Scenario: Admin actions follow state and permissions

- **GIVEN** admin rows are rendered
- **WHEN** backend actions are present
- **THEN** pending may expose view, authorize, edit, cancel
- **AND** authorized may expose view, edit, cancel
- **AND** checked-in, checked-out, and cancelled expose view unless additional operational actions are explicitly granted

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

### Requirement: Admin visit schedule defaults to current date and start time

The admin visit creation form SHALL initialize new empty forms with `visit_date` set to the browser's current local date and `start_time` set to the browser's exact current local time when the schedule step renders on screen. The values SHALL use the existing date and time input formats.

The form SHALL NOT set a default `end_time`. Restored in-progress form state SHALL NOT be overwritten by these defaults.

#### Scenario: New visit form opens with current date and time

- **GIVEN** an admin opens `/admin/visits/new` without restored form state
- **WHEN** the schedule step is reached
- **THEN** the date input is preloaded with the browser's current local date
- **AND** the start time input is preloaded with the browser's exact current local time in `HH:mm` format
- **AND** the start time is not rounded to a time interval
- **AND** the end time input remains empty

#### Scenario: Defaults are included in summary before manual edit

- **GIVEN** an admin opens a new empty visit form
- **WHEN** the admin reaches the authorization summary before changing schedule values
- **THEN** the summary uses the preloaded current date and start time

#### Scenario: Restored form values are preserved

- **GIVEN** an admin has an in-progress visit creation form saved in browser session state
- **WHEN** the admin returns to `/admin/visits/new`
- **THEN** the restored visit date and start time remain unchanged
- **AND** they are not replaced by the current date/time defaults

#### Scenario: Server validation remains authoritative

- **GIVEN** a client submits a visit with invalid or missing schedule values
- **WHEN** the backend processes the visit creation request
- **THEN** existing server-side visit schedule validation still determines whether the visit is accepted

### Requirement: Visit actions use dropdowns

The system SHALL place row, table, and detail actions in `VisitActionsDropdown` or an equivalent dropdown, never as inline mutation buttons.

#### Scenario: Operational table uses dropdown actions

- **GIVEN** a concierge can view or operate a row
- **WHEN** the table is rendered
- **THEN** allowed actions are inside the row dropdown

#### Scenario: Detail uses More actions dropdown

- **GIVEN** a user opens visit detail
- **WHEN** actions are available
- **THEN** they are exposed through Más acciones

### Requirement: Cross-organization and cross-property access is denied

The system MUST deny records and actions outside the current organization or assigned/contextual property scope.

#### Scenario: Cross-organization record is inaccessible

- **GIVEN** a visit belongs to organization B
- **WHEN** an actor in organization A requests it
- **THEN** policy scope excludes it
- **AND** mutations are denied

#### Scenario: Property-scoped actor cannot access unassigned property

- **GIVEN** a property admin or concierge is assigned only to P
- **WHEN** a visit from Q is requested
- **THEN** it is excluded or denied

### Requirement: User-facing visit text is internationalized

The system SHALL source visible labels, statuses, actions, validation feedback, and empty/loading states from i18n in Spanish, English, and Portuguese.

#### Scenario: Visit surfaces use translated text

- **GIVEN** a supported locale is active
- **WHEN** a visit page, drawer, modal, dropdown, or error is rendered
- **THEN** visible text uses the locale catalog

### Requirement: Visit creation notifies unit authorizers

When an administrative visit is created for a unit, the system SHALL create a push `Notification` for each active resident authorizer of that unit (an active `UnitOccupancy` with `can_authorize_visits` true), so that residents who can authorize entry are informed a visit was scheduled for their unit.

#### Scenario: Visit creation notifies the unit's active authorizers

- **GIVEN** unit U has one or more active `UnitOccupancy` records with `can_authorize_visits: true`
- **WHEN** an authorized admin creates a visit for U
- **THEN** the system creates one push `Notification` per active authorizing resident of U
- **AND** each `Notification` references the created visit as its notifiable record

#### Scenario: Residents of other units are not notified

- **GIVEN** unit U belongs to residential property P, which contains other units
- **AND** those other units have their own active resident authorizers
- **WHEN** an authorized admin creates a visit for U
- **THEN** residents of units other than U do not receive a notification for this visit

#### Scenario: Unit with no active authorizer produces no notification

- **GIVEN** unit U has no active `UnitOccupancy` with `can_authorize_visits: true`
- **WHEN** an authorized admin creates a visit for U
- **THEN** the system creates no `Notification` records for this visit

#### Scenario: Notification delivery does not affect visit creation outcome

- **GIVEN** an authorized admin creates a valid visit for a unit with active authorizers
- **WHEN** push delivery to those authorizers' devices fails or is delayed
- **THEN** the visit is still created and returned as successful

### Requirement: Visit tracks aggregate notification delivery status

The system SHALL track, on the visit itself, whether its resident-notification attempt succeeded, failed, or had no one to reach, so an admin can see the outcome without inspecting individual `Notification` records.

#### Scenario: No active authorizer for the unit

- **GIVEN** a visit is created for a unit with no active resident authorizer
- **WHEN** notification processing completes
- **THEN** the visit's notification status is `no_recipients`

#### Scenario: Authorizers exist but none has a registered device

- **GIVEN** a visit is created for a unit whose active authorizers have no registered device token
- **WHEN** notification processing completes
- **THEN** the visit's notification status is `no_recipients`
- **AND** no push delivery attempt is recorded as having been made

#### Scenario: At least one delivery succeeds

- **GIVEN** a visit's unit has multiple active authorizers with registered device tokens
- **WHEN** at least one of those deliveries succeeds, regardless of the others
- **THEN** the visit's notification status is `delivered`

#### Scenario: All delivery attempts fail

- **GIVEN** a visit's unit has one or more active authorizers with registered device tokens
- **WHEN** every delivery attempt to those tokens fails
- **THEN** the visit's notification status is `failed`

### Requirement: Admin can manually resend a failed visit notification

The system SHALL allow an authorized admin to manually resend the notification for a visit whose notification status is `failed`, retrying delivery to the same residents originally targeted. The resend action SHALL NOT be available for any other notification status.

#### Scenario: Admin resends a failed notification

- **GIVEN** a visit's notification status is `failed`
- **WHEN** an authorized admin triggers the resend action
- **THEN** the system retries delivery to the same residents from the original notification attempt
- **AND** the visit's notification status returns to `pending` while the retry is in flight

#### Scenario: Resend targets the original residents, not currently active ones

- **GIVEN** a visit's notification status is `failed`
- **AND** the unit's active resident authorizers have changed since the visit was created
- **WHEN** an authorized admin triggers the resend action
- **THEN** the system retries delivery only to the residents from the original notification attempt

#### Scenario: Resend is unavailable when there was no one to notify

- **GIVEN** a visit's notification status is `no_recipients`
- **WHEN** an admin views the visit
- **THEN** the resend action is not available

#### Scenario: Resend is unavailable once delivered

- **GIVEN** a visit's notification status is `delivered`
- **WHEN** an admin views the visit
- **THEN** the resend action is not available

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
