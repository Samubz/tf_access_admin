# Bulk Import People

## Purpose

Define how bulk import classifies each row against existing identities without merging ambiguous identities automatically, and how it routes rows that require invitation, incorporation, review, or conflict resolution.

## ADDED Requirements

### Requirement: Row classification

The system SHALL classify each imported row as one of: ready to create person, ready to link person, requires invitation, requires incorporation, requires review, conflict, duplicate, or invalid — using the identity resolution service.

#### Scenario: New person is ready to create

- **GIVEN** a row with no matching identity
- **WHEN** the row is classified
- **THEN** it is marked ready to create person

#### Scenario: Existing person without account requires invitation

- **GIVEN** a row matching an existing person without a `User`
- **WHEN** the row is classified
- **THEN** it is marked requires invitation
- **AND** does not create a new person

#### Scenario: Existing person with account requires incorporation

- **GIVEN** a row matching an existing person who has a `User`
- **WHEN** the row is classified
- **THEN** it is marked requires incorporation
- **AND** does not create a new account

#### Scenario: Ambiguous match requires review

- **GIVEN** a row with only partial matching data
- **WHEN** the row is classified
- **THEN** it is marked requires review
- **AND** is not merged automatically

### Requirement: No automatic merge on import

The system SHALL NOT merge ambiguous identities during bulk import and MUST NOT overwrite an existing person or user with row-supplied data.

#### Scenario: Conflict between document and email

- **GIVEN** a row whose document matches one identity and whose email belongs to another
- **WHEN** the row is classified
- **THEN** it is marked conflict
- **AND** no identity is created or modified

#### Scenario: Email used by another identity

- **GIVEN** a row whose email is used by a different identity
- **WHEN** the row is classified
- **THEN** it is marked conflict or requires review
- **AND** is not auto-linked

### Requirement: Bulk import never grants operational roles

The system SHALL restrict bulk import to client-level people. Imported rows MUST NOT assign operational roles; those follow the individual onboarding flow with holder acceptance.

#### Scenario: Imported person is client-level only

- **WHEN** a row is imported
- **THEN** the resulting membership is client-level
- **AND** no operational role is assigned

### Requirement: Pending states are respected on import

The system SHALL account for existing pending invitations and existing incorporations when classifying rows, treating already-satisfied relationships idempotently.

#### Scenario: Pending invitation is not duplicated

- **GIVEN** a row matching a person with a pending invitation
- **WHEN** the row is classified
- **THEN** the system does not create a duplicate invitation

#### Scenario: Existing incorporation is idempotent

- **GIVEN** a row matching a person already incorporated into the organization
- **WHEN** the row is processed
- **THEN** the system creates no duplicate relationship
