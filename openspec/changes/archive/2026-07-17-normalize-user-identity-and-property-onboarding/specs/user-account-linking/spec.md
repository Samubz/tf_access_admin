# User Account Linking

## Purpose

Define how authentication accounts (`User`) are created and linked to a per-organization `Person`. Linking to an existing account is resolved automatically by confirmed email; joining a new context is governed by the join-activation rules (see `property-onboarding`). The system never creates a second account for an email that already has one, keeps managers email-blind, and supports unlinking with full traceability.

## ADDED Requirements

### Requirement: No second account for an existing confirmed email

The system SHALL NOT create a new `User` when a `User` already exists for the supplied confirmed email. The person is instead linked to the existing account.

#### Scenario: Existing confirmed email is reused, not duplicated

- **GIVEN** a `User` exists with a confirmed email
- **WHEN** a manager invites a person with that email
- **THEN** the system links the person to the existing account
- **AND** does not create a new `User`

#### Scenario: New email invites account creation

- **GIVEN** no account exists for the supplied email
- **WHEN** a manager invites a person with that email
- **THEN** the system invites the person to create an account
- **AND** links the account to the person upon confirmation

### Requirement: Automatic linking by confirmed email

The system SHALL link a `Person` to an existing `User` automatically when the confirmed email matches, without an "is this you?" challenge. The safety control for the resulting relationship is the join-activation rule, not the identity match (see `property-onboarding`).

#### Scenario: Link is established by confirmed email match

- **GIVEN** a person carrying an email that matches a confirmed account
- **WHEN** the person is created or invited
- **THEN** the system links the person to that account
- **AND** the resulting membership follows the join-activation rules

### Requirement: Manager never selects an existing account

The system SHALL NOT let a manager browse, select, or view existing accounts by email or other identifiers when creating or inviting a person. The manager supplies an email; the system resolves the account server-side.

#### Scenario: No account picker exposed to the manager

- **WHEN** a manager creates or invites a person
- **THEN** the system does not present a list of existing accounts or their emails to choose from

### Requirement: Unconfirmed accounts cannot use the application

The system SHALL prevent a `User` who has not confirmed their account from using the application, even when the account has been linked to a `Person` or incorporated into an organization. Linking and incorporation MAY proceed, but access is gated on confirmation.

#### Scenario: Unconfirmed user is blocked from the application

- **GIVEN** a linked `User` who has not confirmed their account
- **WHEN** the user attempts to use the application
- **THEN** the system denies access until the account is confirmed

#### Scenario: Incorporation of an unconfirmed account still links

- **GIVEN** an unconfirmed account matching an invited email
- **WHEN** the organization incorporates it
- **THEN** the system links the account and creates the membership per the join rules
- **AND** the user cannot use the application until confirmation

### Requirement: Unlink with traceability

The system SHALL allow unlinking a `User` from a `Person` without deleting the `Person` or its unit relationships, and SHALL record the actor, reason, and previous and resulting state.

#### Scenario: Unlinking preserves the person and relationships

- **GIVEN** a `Person` linked to a `User` with active ownerships
- **WHEN** an authorized actor unlinks the account
- **THEN** the `Person` and its ownerships remain
- **AND** an audit record captures actor, reason, and state transition

### Requirement: Account creation input is tenant-safe

The system SHALL derive tenant identifiers from the request context and MUST NOT accept tenant identifiers from the client for account creation or linking.

#### Scenario: Tenant not accepted from client

- **WHEN** a client submits an account creation request including a tenant identifier
- **THEN** the system ignores the client-supplied tenant identifier
- **AND** uses the context organization
