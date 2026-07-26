# Concierge Visit Access Flow

## Purpose

Define the property-scoped concierge workflow for finding expected visitors, identifying visitors currently inside, and recording check-in/check-out with capability-based authorization, minimal data exposure, complete transition history, and strict organization/property isolation.

## ADDED Requirements

### Requirement: Concierge operates only assigned properties

The system SHALL expose the concierge visit-access flow only for residential properties where the authenticated user's organizational `Person` has an active and currently valid concierge `StaffAssignment` and the required property-scoped capability.

#### Scenario: Concierge sees visits for assigned property

- **GIVEN** concierge user C has an active `StaffAssignment` for property P
- **AND** C has `view_authorized_visits` for P
- **WHEN** C opens the concierge visit-access screen for P
- **THEN** the operational scope may return visits for P
- **AND** no visit from another property or organization is returned

#### Scenario: Inactive assignment grants no access

- **GIVEN** C's only concierge assignment for P is inactive, future-dated, or expired
- **WHEN** C opens the concierge visit-access screen
- **THEN** access to P is denied
- **AND** no visit data for P is returned

### Requirement: Concierge searches visits by document name and unit

The system SHALL allow property-scoped operational search by visitor document, visitor name, and unit identifier or display name.

#### Scenario: Search by visitor document

- **GIVEN** C may view operational visits for property P
- **WHEN** C searches for a visitor document
- **THEN** matching visit results are restricted to P and the current organization

#### Scenario: Search by visitor name

- **GIVEN** C may view operational visits for P
- **WHEN** C searches by a full or partial normalized visitor name
- **THEN** matching visit results for P are returned with minimal operational data

#### Scenario: Search by unit

- **GIVEN** C may view operational visits for P
- **WHEN** C searches by unit identifier or display name
- **THEN** matching visit results are restricted to units in P

#### Scenario: Search cannot discover another property

- **GIVEN** a matching visitor or unit exists only in property Q
- **AND** C is assigned only to P
- **WHEN** C performs the search from P
- **THEN** no result from Q is returned
- **AND** the response does not confirm inaccessible visit details

### Requirement: Concierge sees visits expected today

The system SHALL provide an Expected today list containing authorized visits for the selected property whose schedule or validity window intersects the property's current local day.

#### Scenario: Expected today uses property local day

- **GIVEN** property P has an operational timezone
- **AND** visit V intersects P's local current day
- **WHEN** the assigned concierge opens Expected today
- **THEN** V is evaluated using P's local day rather than the server timezone

#### Scenario: Authorized visit expected today is listed

- **GIVEN** visit V belongs to property P
- **AND** V is `authorized`
- **AND** V's schedule or validity window intersects today's local date for P
- **WHEN** an assigned concierge opens Expected today
- **THEN** V is listed with minimal visitor, unit, host, schedule, status, and allowed actions

#### Scenario: Visit from another day is excluded

- **GIVEN** authorized visit V does not intersect today's local date for P
- **WHEN** the concierge opens Expected today
- **THEN** V is excluded from that list

#### Scenario: Cancelled and expired visits are excluded from Expected today

- **GIVEN** visits in P are `cancelled`, persistently `expired`, or effectively expired by `valid_until`
- **WHEN** the concierge opens Expected today
- **THEN** those visits are excluded from the normal list

### Requirement: Concierge sees visits currently inside

The system SHALL provide a Currently inside list containing visits in the selected property with status `checked_in`, a recorded `checked_in_at`, and no recorded `checked_out_at`.

#### Scenario: Checked-in visit appears inside

- **GIVEN** visit V in property P is `checked_in`
- **AND** V has `checked_in_at`
- **AND** V has no `checked_out_at`
- **WHEN** the assigned concierge opens Currently inside
- **THEN** V is listed
- **AND** its current duration may be calculated from `checked_in_at`

#### Scenario: Checked-out visit is not currently inside

- **GIVEN** visit V has transitioned to `checked_out`
- **WHEN** the concierge opens Currently inside
- **THEN** V is excluded

### Requirement: State determines the operational instruction

The system SHALL expose backend-computed operational status and actions without allowing the frontend to infer permission from status alone.

#### Scenario: Authorized valid visit offers entry

- **GIVEN** V is `authorized` and within its validity window
- **AND** C is allowed to check in V
- **WHEN** V is serialized for portería
- **THEN** its operational label is Autorizada
- **AND** `Registrar ingreso` is available

#### Scenario: Checked-in visit offers exit

- **GIVEN** V is `checked_in`
- **AND** C is allowed to check out V
- **WHEN** V is serialized
- **THEN** its operational label is Dentro de la propiedad
- **AND** `Registrar salida` is available

#### Scenario: Cancelled search result denies entry

- **GIVEN** V in the assigned property is `cancelled`
- **WHEN** a sufficiently specific operational search resolves V
- **THEN** the system may return a minimal Cancelada result
- **AND** no check-in action is exposed

#### Scenario: Persisted expired visit requests new authorization

- **GIVEN** V is `expired`
- **WHEN** a sufficiently specific operational search resolves V
- **THEN** the system may return a minimal Expirada result
- **AND** the instruction is to request a new authorization
- **AND** no check-in action is exposed

#### Scenario: Authorized visit past valid-until is effectively expired

- **GIVEN** V remains persisted as `authorized`
- **AND** the current time is after `valid_until`
- **WHEN** V is evaluated for entry
- **THEN** its effective operational status is Expirada
- **AND** no persisted state transition is required merely to calculate that status
- **AND** check-in is denied

### Requirement: Only an authorized valid visit permits check-in

The system SHALL permit check-in only when the visit is `authorized`, temporally valid, belongs to the concierge's assigned property, and the authenticated user has `register_visit_entry` for that property.

#### Scenario: Authorized visit before valid-from is not yet valid

- **GIVEN** V remains persisted as `authorized`
- **AND** the current time is before `valid_from`
- **WHEN** V is evaluated for entry
- **THEN** its effective operational status is not yet valid
- **AND** no check-in action is exposed
- **AND** check-in is denied

#### Scenario: Eligible concierge registers entry

- **GIVEN** V in property P is `authorized` and temporally valid
- **AND** C has an active concierge assignment and `register_visit_entry` for P
- **WHEN** C confirms check-in
- **THEN** the transition is permitted

#### Scenario: Cancelled visit cannot check in

- **GIVEN** V is `cancelled`
- **WHEN** C attempts check-in
- **THEN** the action is rejected
- **AND** V remains `cancelled`

#### Scenario: Expired visit cannot check in

- **GIVEN** V is `expired` or its `valid_until` has passed
- **WHEN** C attempts check-in
- **THEN** the action is rejected
- **AND** no entry timestamp or actor is recorded

#### Scenario: Non-authorized visit cannot check in

- **GIVEN** V has any state other than `authorized`
- **WHEN** C attempts check-in
- **THEN** the action is rejected

### Requirement: Check-in records User actor timestamp and state

The system SHALL atomically transition an eligible visit from `authorized` to `checked_in`, persist `checked_in_at`, and set `checked_in_by_id` to the authenticated `User`.

#### Scenario: Successful check-in is persisted

- **GIVEN** all check-in preconditions pass
- **WHEN** C confirms entry
- **THEN** V becomes `checked_in`
- **AND** `checked_in_at` records the effective entry time
- **AND** `checked_in_by_id` references C's `User`
- **AND** it does not reference C's `Person`

### Requirement: Active visit cannot be checked in twice

The system MUST prevent a second active check-in for the same visit before checkout, including sequential or concurrent attempts.

#### Scenario: Sequential duplicate check-in is rejected

- **GIVEN** V is already `checked_in`
- **WHEN** C attempts check-in again
- **THEN** the action is rejected
- **AND** the original `checked_in_at` and `checked_in_by_id` remain unchanged
- **AND** no duplicate functional event is recorded

#### Scenario: Concurrent duplicate check-in produces one entry

- **GIVEN** two authorized requests attempt to check in V concurrently
- **WHEN** both requests are processed
- **THEN** at most one transition to `checked_in` commits
- **AND** only one active entry and one successful `checked_in` functional event exist

### Requirement: Only checked-in visits permit check-out

The system SHALL permit checkout only when the visit is `checked_in`, belongs to the concierge's assigned property, and the authenticated user has `register_visit_exit` for that property.

#### Scenario: Eligible concierge registers exit

- **GIVEN** V in property P is `checked_in`
- **AND** C has an active concierge assignment and `register_visit_exit` for P
- **WHEN** C confirms checkout
- **THEN** the transition is permitted

#### Scenario: Visit not checked in cannot check out

- **GIVEN** V has any state other than `checked_in`
- **WHEN** C attempts checkout
- **THEN** the action is rejected
- **AND** no checkout timestamp or actor is recorded

### Requirement: Check-out records User actor timestamp and state

The system SHALL atomically transition an eligible visit from `checked_in` to `checked_out`, persist `checked_out_at`, and set `checked_out_by_id` to the authenticated `User`.

#### Scenario: Successful check-out is persisted

- **GIVEN** all checkout preconditions pass
- **WHEN** C confirms exit
- **THEN** V becomes `checked_out`
- **AND** `checked_out_at` records the effective exit time
- **AND** `checked_out_by_id` references C's `User`
- **AND** it does not reference C's `Person`
- **AND** V is removed from Currently inside

#### Scenario: Duplicate check-out is rejected

- **GIVEN** V has already transitioned to `checked_out`
- **WHEN** C attempts checkout again
- **THEN** the action is rejected
- **AND** the original `checked_out_at` and `checked_out_by_id` remain unchanged
- **AND** no duplicate functional history record is recorded

#### Scenario: Check-out before check-in time is rejected

- **GIVEN** V is `checked_in`
- **AND** a checkout time earlier than `checked_in_at` is submitted
- **WHEN** C confirms checkout
- **THEN** the action is rejected
- **AND** no checkout timestamp or actor is recorded

### Requirement: Concierge cannot operate another property's visit

The system MUST deny check-in and checkout when the visit does not belong to a property for which the authenticated user has the corresponding active assignment and capability.

#### Scenario: Check-in denied cross-property

- **GIVEN** C has `register_visit_entry` only for property P
- **AND** V belongs to property Q
- **WHEN** C attempts check-in for V
- **THEN** authorization is denied
- **AND** V is unchanged

#### Scenario: Check-out denied cross-property

- **GIVEN** C has `register_visit_exit` only for property P
- **AND** V belongs to property Q
- **WHEN** C attempts checkout for V
- **THEN** authorization is denied
- **AND** V is unchanged

#### Scenario: Cross-organization operation is denied

- **GIVEN** C operates in organization O
- **AND** V belongs to organization Q
- **WHEN** C attempts any portería operation on V
- **THEN** authorization is denied without exposing V's details

### Requirement: Entry and exit capabilities are independently required

The system SHALL authorize check-in with `register_visit_entry` and checkout with `register_visit_exit`, evaluated through `Authorization::Resolver` and `VisitPolicy`.

#### Scenario: User without entry capability cannot check in

- **GIVEN** user C may view V but lacks `register_visit_entry` for V's property
- **WHEN** C attempts check-in
- **THEN** authorization is denied

#### Scenario: User without exit capability cannot check out

- **GIVEN** user C may view V but lacks `register_visit_exit` for V's property
- **WHEN** C attempts checkout
- **THEN** authorization is denied

#### Scenario: UI does not substitute for policy

- **GIVEN** a mutation request is submitted without an exposed button
- **WHEN** the backend evaluates the request
- **THEN** `VisitPolicy` and `Authorization::Resolver` still enforce the corresponding capability and property scope

### Requirement: Every access transition records audit and functional history

The system SHALL record technical audit and user-visible functional history for every successful check-in and checkout in the same atomic operation as the visit transition.

#### Scenario: Check-in records history

- **GIVEN** V successfully transitions to `checked_in`
- **WHEN** the transaction commits
- **THEN** technical audit reflects the changed state, actor, timestamp, and audited metadata
- **AND** one functional `checked_in` event records from/to status, actor `User`, occurrence time, notes, and allowed metadata

#### Scenario: Check-out records history

- **GIVEN** V successfully transitions to `checked_out`
- **WHEN** the transaction commits
- **THEN** technical audit reflects the changed state, actor, timestamp, and audited metadata
- **AND** one functional `checked_out` event records from/to status, actor `User`, occurrence time, notes, and allowed metadata

#### Scenario: Failed transition leaves no partial history

- **GIVEN** persistence or functional history creation fails
- **WHEN** check-in or checkout is rolled back
- **THEN** visit state, timestamps, actors, audit effects, and functional events remain coherent

### Requirement: Concierge serializer exposes only minimal operational data

The system SHALL serialize only data necessary to identify the visit, make an access decision, perform an allowed transition, and display minimal operational history.

#### Scenario: Minimal portería payload is returned

- **GIVEN** C may view V through the concierge flow
- **WHEN** V is serialized
- **THEN** the payload may include minimal visitor identity, unit, host summary, schedule/validity, state, operational timestamps, summarized actors, allowed metadata, duration, actions, and minimal functional timeline
- **AND** permissions/actions are computed by backend policy

#### Scenario: Administrative person data is omitted

- **GIVEN** C lacks administrative person-management capability
- **WHEN** V is serialized for portería
- **THEN** full person profiles, memberships, ownership/occupancy details, global role data, administrative notes, and technical audit logs are omitted

### Requirement: Access data supports future operational reporting

The system SHALL preserve sufficient visit, unit, authorization, actor, and timestamp data to support future reporting without requiring a complete reporting module in this change.

#### Scenario: Completed visit duration is derivable

- **GIVEN** V has both `checked_in_at` and `checked_out_at`
- **WHEN** duration is requested by a future report
- **THEN** time inside can be derived from those timestamps

#### Scenario: Visits still inside are derivable

- **GIVEN** visits in P include records in multiple states
- **WHEN** a future operational query asks who remains inside
- **THEN** visits with state `checked_in` and no `checked_out_at` can be identified

### Requirement: Resident-created visits use the same concierge flow

The system SHALL treat an authorized visit created through `residential-visit-management` like any other authorized visit in the same property.

#### Scenario: Resident-created authorized visit appears in portería

- **GIVEN** a resident creates an authorized visit for unit U in property P
- **AND** the visit qualifies as expected today
- **WHEN** an assigned concierge views Expected today
- **THEN** the visit is included
- **AND** the same check-in/check-out rules apply
