# residential-visit-management

## MODIFIED Requirements

### Requirement: Resident registers a visit through a private authenticated API

The system SHALL provide a private authenticated API contract, distinct from the administrative visit flow, through which a resident submits a unit, visitor name, visitor email, optional visitor document, optional visitor phone, and visit date/time.

#### Scenario: Authenticated resident submits a valid private request

- **GIVEN** a `User` is authenticated in organization O
- **AND** the user's `Person` has an active relationship with unit U in O
- **AND** the user is allowed to create and authorize visits for U
- **WHEN** the user submits a visitor name, a valid visitor email and a visit date/time through the private API
- **THEN** the system creates a visit for U
- **AND** the operation does not use an admin visit screen or admin Inertia flow

#### Scenario: Missing or invalid visitor email is rejected

- **WHEN** the resident submits a visitor without email, or with a malformed email
- **THEN** the system returns `422` with a localized error
- **AND** no `Person` or `Visit` is persisted

#### Scenario: Unauthenticated request is rejected

- **GIVEN** no valid private API authentication is present
- **WHEN** a visit registration is submitted
- **THEN** the request is rejected
- **AND** no `Person`, `Visit`, or functional history record is persisted

## ADDED Requirements

### Requirement: Visitor person is resolved by email within the organization

The system SHALL resolve the visitor `Person` inside the current organization by document when provided, otherwise by normalized email (lower-cased, trimmed), and SHALL create a new `Person` when no match exists. The system MUST NOT merge existing persons.

#### Scenario: Existing person by email is reused

- **GIVEN** a `Person` in O with email `ana@example.com`
- **WHEN** a resident invites `Ana@Example.com`
- **THEN** the visit points to that existing `Person` and no new `Person` is created

#### Scenario: New person is created

- **GIVEN** no `Person` in O with the submitted email or document
- **WHEN** the resident submits the invitation
- **THEN** the system creates a `Person` in O with the display name, email, phone and document provided

#### Scenario: Same email in another organization is not reused

- **GIVEN** a `Person` with the same email exists only in organization P
- **WHEN** a resident of O invites that email
- **THEN** the system creates a separate `Person` in O

#### Scenario: Conflicting identity is rejected

- **GIVEN** a `Person` in O with document D and email `x@example.com`
- **WHEN** a resident submits document D with email `y@example.com`
- **THEN** the system returns `422` with a localized conflict error and persists nothing

### Requirement: Visitor is notified after the visit is created

After a resident visit is persisted, the system SHALL notify the visitor outside the creation transaction: by push and email when the visitor `Person` has a linked account, by linking and then notifying when a confirmed account with that email exists, or by issuing an onboarding invitation email when no account exists. Notification failures MUST NOT fail visit creation.

#### Scenario: Visitor with linked account gets push and email

- **GIVEN** the visitor `Person` is linked to a `User` with a registered device token
- **WHEN** the visit is created
- **THEN** a `Notification` of type `visit_invitation` and channel `push` is enqueued for that person
- **AND** an invitation email with the visit details is enqueued

#### Scenario: Existing confirmed account is linked

- **GIVEN** the visitor `Person` has no `user_id` and a confirmed `User` exists with the same email
- **WHEN** the visit is created
- **THEN** the `User` is linked to the `Person`, a `visitor` membership in O is created if the user had none
- **AND** the visitor is notified as in the linked-account scenario

#### Scenario: Visitor without account receives account invitation

- **GIVEN** no `User` exists with the visitor email
- **WHEN** the visit is created
- **THEN** an `OnboardingRequest` with relationship `visitor` is issued for the `Person`
- **AND** an email with the visit details and a single-use acceptance link is enqueued

#### Scenario: Pending invitation is not duplicated

- **GIVEN** the visitor `Person` already has a pending `OnboardingRequest`
- **WHEN** another visit is created for the same visitor
- **THEN** no new token is issued
- **AND** an email with the visit details, without acceptance link, is enqueued

#### Scenario: Notification error does not block creation

- **WHEN** issuing the invitation raises an unexpected error
- **THEN** the visit remains created with status `authorized`
- **AND** the error is recorded on the visit metadata
