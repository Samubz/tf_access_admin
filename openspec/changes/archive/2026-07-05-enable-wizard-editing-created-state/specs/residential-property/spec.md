## MODIFIED Requirements

### Requirement: Property has controlled status

The system SHALL limit property status to `draft`, `created`, `configured`, `active`, `inactive`, or `archived`.

`draft` represents wizard setup in progress. `created` represents wizard setup completed but still editable. `configured` represents confirmed setup. `active` represents fully operational property usage. `inactive` and `archived` represent non-operational states.

The setup wizard SHALL treat `created`, `configured`, and `active` as editable statuses for property identity fields, property type, building format, manual sections, and manual units. Property identity fields are `address_line`, `city`, `country`, `name`, `property_type`, `region`, and `timezone`.

The system SHALL derive `normalized_name` from `name` using the same normalization convention as `PropertySection#assign_normalized_name`. The system SHALL derive property `code` from the property type abbreviation and `normalized_name`, reusing the existing implemented code-generation convention. If a generated property `code` collides with another property, the system SHALL reject the change and tell the client that the property name must be changed.

Status transitions SHALL be constrained as follows: `draft` can transition to `created` or `configured`; `created` can transition to `configured`; `configured` can transition only to `active`; and `active` can transition only to `archived`.

Ordinary non-wizard property creation SHALL continue to default according to the ordinary creation flow. Wizard creation SHALL use `draft` initially and transition through the setup lifecycle.

#### Scenario: New property defaults to active

- **WHEN** an ordinary administrative property is created outside the setup wizard without specifying status
- **THEN** its status is `active`

#### Scenario: Wizard draft property starts as draft

- **WHEN** the setup wizard initializes a new property
- **THEN** its status is `draft`

#### Scenario: Setup can leave property created

- **GIVEN** a valid draft property completes setup without final confirmation
- **WHEN** the setup completion action chooses the editable outcome
- **THEN** the property transitions to `created`

#### Scenario: Setup can confirm property

- **GIVEN** a valid draft or created property is ready for confirmation
- **WHEN** the confirmation action is accepted
- **THEN** the property transitions to `configured`

#### Scenario: Unknown status is rejected

- **WHEN** create or update receives a status outside `draft`, `created`, `configured`, `active`, `inactive`, and `archived`
- **THEN** validation rejects the value

#### Scenario: Configured property can become active

- **GIVEN** an authorized actor manages configured property P
- **WHEN** they perform the explicit activation action
- **THEN** P becomes `active`

#### Scenario: Active property can become archived

- **GIVEN** an authorized actor manages active property P
- **WHEN** they archive P
- **THEN** P becomes `archived`

#### Scenario: Active property cannot become configured

- **GIVEN** property P has status `active`
- **WHEN** an actor attempts to transition P to `configured`
- **THEN** the transition is rejected

#### Scenario: Configured property cannot become created

- **GIVEN** property P has status `configured`
- **WHEN** an actor attempts to transition P to `created`
- **THEN** the transition is rejected

#### Scenario: Created property remains editable

- **GIVEN** property P has status `created`
- **WHEN** an authorized setup user edits P through the setup wizard
- **THEN** property fields, property type, structure format, manual sections, and manual units may be changed according to setup rules

#### Scenario: Configured property remains editable

- **GIVEN** property P has status `configured`
- **WHEN** an authorized setup user edits P through the setup wizard
- **THEN** property fields, property type, building format, manual sections, and manual units may be changed according to setup rules

#### Scenario: Active property remains editable

- **GIVEN** property P has status `active`
- **WHEN** an authorized setup user edits P through the setup wizard
- **THEN** property fields, property type, building format, manual sections, and manual units may be changed according to setup rules

#### Scenario: Name change regenerates normalized name and code

- **GIVEN** property P has a name-derived `normalized_name` and `code`
- **WHEN** an authorized setup user changes P's `name`
- **THEN** P's `normalized_name` is regenerated from the new `name`
- **AND** P's `code` is regenerated from P's property type abbreviation and regenerated `normalized_name`

#### Scenario: Name change with code collision is rejected

- **GIVEN** property P has status `created`, `configured`, or `active`
- **AND** changing P's `name` would generate a `code` already used by another property
- **WHEN** an authorized setup user submits the name change
- **THEN** the change is rejected
- **AND** the client is told to change the property name
