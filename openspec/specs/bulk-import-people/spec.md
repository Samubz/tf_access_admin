# bulk-import-people Specification

## Purpose
TBD - created by archiving change normalize-user-identity-and-property-onboarding. Update Purpose after archive.
## Requirements
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

### Requirement: Import classifies rows and lets the manager act

The system SHALL classify each row via the classification service and, on import, create only the people for `ready_to_create_person` rows. Rows requiring invitation, incorporation, review, or flagged as conflict SHALL be recorded with their classification for the manager to act on explicitly; the import MUST NOT auto-send invitations or auto-create onboarding requests. Duplicates are idempotent; invalid rows are rejected. It MUST NOT merge identities automatically.

#### Scenario: Ready rows create people; action rows are not auto-sent

- **GIVEN** a batch with a new-person row and an existing-account row
- **WHEN** the import runs
- **THEN** the new-person row creates a person
- **AND** the existing-account row is recorded as requires-incorporation without creating an account or sending an email

#### Scenario: Manager triggers invitations after review

- **GIVEN** rows classified as requires-invitation/incorporation
- **WHEN** the manager explicitly triggers the action (per row or in bulk)
- **THEN** the system creates the corresponding onboarding requests and deliveries

#### Scenario: Conflict rows are not applied

- **GIVEN** a row classified as conflict
- **WHEN** the import runs
- **THEN** the system does not create or modify any identity for that row

### Requirement: Import UI surfaces the classification per row

The system SHALL display the classification of each row in the bulk-import UI so a manager can review before or after applying.

#### Scenario: Row states are visible

- **WHEN** a manager reviews an import
- **THEN** each row shows its classification (ready/invitation/incorporation/review/conflict/duplicate/invalid)

