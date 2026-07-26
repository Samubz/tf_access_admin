## ADDED Requirements

### Requirement: Manual wizard unit management supports editable setup statuses

Manual wizard unit creation, edit, and removal SHALL operate for draft, created, configured, and active setup contexts. For created, configured, and active properties, the wizard SHALL expose manual unit management and SHALL NOT offer automatic unit generation.

Unit mutations SHALL remain scoped to the current organization, current property, and eligible sections, and SHALL continue requiring `manage_units`.

When a user removes a unit through the wizard (individually or as part of a structure reset), the system SHALL check whether the unit has any `unit_ownerships`, `lease_contracts`, `unit_occupancies`, or `visits` records. If none exist, the system SHALL soft-delete the unit directly via the existing `Units::SoftDelete`, without requiring an additional confirmation beyond the ordinary delete action. If any exist, the system SHALL require an explicit user confirmation and archive the unit via the existing `Units::Archive` instead of soft-deleting it. This change does not modify `Units::Archive` or `Units::Reactivate`: reactivating an archived unit remains available through ordinary, non-wizard unit administration exactly as it does today; the wizard simply never exposes a reactivate action and never re-surfaces an archived unit for editing.

#### Scenario: Created property can manage manual units

- **GIVEN** property P has status `created`
- **AND** a user has `manage_units` for P
- **WHEN** they create, edit, or soft-delete a unit through the wizard manual unit mode
- **THEN** the operation is accepted according to the existing unit contract

#### Scenario: Configured property can manage manual units

- **GIVEN** property P has status `configured`
- **AND** a user has `manage_units` for P
- **WHEN** they create, edit, or soft-delete a unit through the wizard manual unit mode
- **THEN** the operation is accepted according to the existing unit contract
- **AND** automatic unit generation is not offered

#### Scenario: Active property can manage manual units

- **GIVEN** property P has status `active`
- **AND** a user has `manage_units` for P
- **WHEN** they create, edit, or soft-delete a unit through the wizard manual unit mode
- **THEN** the operation is accepted according to the existing unit contract
- **AND** automatic unit generation is not offered

#### Scenario: Removing a unit without operational history soft-deletes it directly

- **GIVEN** property P has status `created`, `configured`, or `active`
- **AND** unit U has no `unit_ownerships`, `lease_contracts`, `unit_occupancies`, or `visits` records
- **WHEN** an authorized setup user removes U through the wizard
- **THEN** U is soft-deleted directly
- **AND** no additional confirmation beyond the ordinary delete action is required

#### Scenario: Removing a unit with operational history requires confirmation and archives instead

- **GIVEN** property P has status `created`, `configured`, or `active`
- **AND** unit U has at least one `unit_ownerships`, `lease_contracts`, `unit_occupancies`, or `visits` record
- **WHEN** an authorized setup user attempts to remove U through the wizard
- **THEN** the system requires an explicit confirmation before proceeding
- **AND** upon confirmation, U is archived rather than soft-deleted
- **AND** U is not soft-deleted

#### Scenario: Archived units remain reactivatable outside the wizard

- **GIVEN** unit U was archived through a wizard removal because it had operational history
- **WHEN** an authorized administrator uses ordinary, non-wizard unit management
- **THEN** `Units::Reactivate` is available for U exactly as it is for any other archived unit
- **AND** the wizard itself does not expose a reactivate action for U

#### Scenario: Inactive archived properties cannot manage manual units

- **GIVEN** property P has status `inactive` or `archived`
- **WHEN** a user attempts to create, edit, or soft-delete a unit through wizard manual unit mode
- **THEN** the mutation is rejected
- **AND** no unit is created, edited, or deleted
