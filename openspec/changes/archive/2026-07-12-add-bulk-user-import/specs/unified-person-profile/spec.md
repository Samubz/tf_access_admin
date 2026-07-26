## ADDED Requirements

### Requirement: Bulk user import uses unified person identity
The system SHALL create imported users as `Person` records in the `people` table for the current organization and MUST NOT create `User` login accounts, introduce a separate user identity table, or bypass centralized person deduplication.

#### Scenario: Bulk import creates a person without login access
- **WHEN** a valid bulk user import row is imported
- **THEN** the system creates an active natural `Person`
- **AND** the person has no linked `User` unless an existing supported person flow explicitly links one outside this import

#### Scenario: Bulk import respects centralized deduplication
- **GIVEN** an active person in the current organization already has the same document or normalized email as an imported row
- **WHEN** the import is validated
- **THEN** the system detects the existing person through centralized identity rules
- **AND** does not create a duplicate person during execution

#### Scenario: Bulk import creates organization membership
- **WHEN** a person is created through bulk user import
- **THEN** the system creates or activates the person's organization membership
