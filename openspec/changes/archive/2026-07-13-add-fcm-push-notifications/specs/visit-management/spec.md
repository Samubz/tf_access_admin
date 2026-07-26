## ADDED Requirements

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
