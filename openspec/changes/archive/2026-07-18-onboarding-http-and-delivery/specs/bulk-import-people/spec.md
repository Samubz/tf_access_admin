# Bulk Import People

## ADDED Requirements

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
