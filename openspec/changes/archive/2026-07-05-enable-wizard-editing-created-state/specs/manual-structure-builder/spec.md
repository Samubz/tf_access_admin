## ADDED Requirements

### Requirement: Manual builder supports editable setup statuses

The manual structure builder SHALL operate in draft, created, configured, and active setup contexts. For created, configured, and active properties, the wizard SHALL expose manual section management and SHALL NOT offer quick automatic structure generation.

Manual section creation, edit, and deletion SHALL remain scoped to the current organization and current property, and SHALL continue delegating to the existing section services and hierarchy rules.

Manual section deletion is independent from destructive structure reset. When a user manually deletes one section, the system SHALL check whether the section or any of its associated units has operational history (`unit_ownerships`, `lease_contracts`, `unit_occupancies`, or `visits`). If none has operational history, the system SHALL soft-delete that section and its associated units directly, without requiring an additional confirmation beyond the ordinary delete action, and without deleting unrelated sections or units. If the section or any of its associated units has operational history, the system SHALL instead require an explicit user confirmation and archive the section (via the existing `PropertySections::Archive`) and its associated units (via the existing `Units::Archive`) rather than soft-deleting them; archiving does not cascade a literal `status = archived` write to descendants beyond what `PropertySections::Archive` already does, relying on computed effective status, and the archived section/units are excluded from the wizard per the `property-setup-wizard` capability. Neither path requires the destructive reset confirmation.

#### Scenario: Created property can edit manual structure

- **GIVEN** property P has status `created`
- **WHEN** an authorized setup user opens manual structure editing
- **THEN** they can create, rename, and delete sections according to manual builder rules
- **AND** all mutations remain scoped to P and its organization

#### Scenario: Configured property can edit manual structure

- **GIVEN** property P has status `configured`
- **WHEN** an authorized user opens manual section management from the wizard
- **THEN** they can use manual section actions allowed by their permissions
- **AND** quick automatic structure generation is not offered

#### Scenario: Active property can edit manual structure

- **GIVEN** property P has status `active`
- **WHEN** an authorized user opens manual section management from the wizard
- **THEN** they can use manual section actions allowed by their permissions
- **AND** quick automatic structure generation is not offered

#### Scenario: Manual section delete soft-deletes associated units without operational history

- **GIVEN** property P has status `created`, `configured`, or `active`
- **AND** section S has associated units, none of which has operational history
- **WHEN** an authorized setup user deletes section S through manual structure management
- **THEN** section S is soft-deleted
- **AND** units associated with section S are soft-deleted
- **AND** unrelated sections and units remain unchanged
- **AND** destructive reset confirmation is not required

#### Scenario: Manual section delete requires confirmation and archives when a unit has operational history

- **GIVEN** property P has status `created`, `configured`, or `active`
- **AND** section S has a unit with `unit_ownerships`, `lease_contracts`, `unit_occupancies`, or `visits` records
- **WHEN** an authorized setup user attempts to delete section S through manual structure management
- **THEN** the system requires an explicit confirmation before proceeding
- **AND** upon confirmation, section S and its associated units are archived rather than soft-deleted
- **AND** unrelated sections and units remain unchanged
- **AND** destructive reset confirmation is not required
- **AND** archiving does not write `status = archived` onto descendants beyond what `PropertySections::Archive` already persists

#### Scenario: Inactive archived properties cannot edit manual structure

- **GIVEN** property P has status `inactive` or `archived`
- **WHEN** a user attempts to mutate sections through the setup wizard
- **THEN** the mutation is rejected
- **AND** no section is created, edited, or deleted

### Requirement: Manual builder supports moving a section to a different parent

The wizard SHALL let an authorized setup user move an existing section to a different parent (or to root) using the existing `PropertySections::Move` service and its hierarchy rules, for draft, created, configured, and active setup contexts. This capability is native to the wizard's manual structure step; it is not offered through any page outside the setup wizard.

#### Scenario: Setup user moves a section under a different root

- **GIVEN** property P has root sections A and B, with subsection S under A
- **WHEN** an authorized setup user moves S to be a subsection of B through the wizard
- **THEN** S's parent becomes B
- **AND** the move is rejected if it would violate hierarchy depth, cycle, or sibling-uniqueness rules

#### Scenario: Setup user moves a subsection to root

- **GIVEN** property P has subsection S under root A
- **WHEN** an authorized setup user moves S to root through the wizard
- **THEN** S becomes a root section
