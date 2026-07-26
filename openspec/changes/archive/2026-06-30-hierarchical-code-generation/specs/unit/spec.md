# unit Delta Specification

## MODIFIED Requirements

### Requirement: Unit identifier is normalized canonically

The system SHALL derive `normalized_identifier` from `identifier` through `Units::NormalizeIdentifier` using `DomainCodes::Slug` on the trimmed visible identifier (transliteration, lowercase, whitespace-to-hyphen, strip non-alphanumeric). Uniqueness comparisons MUST use `normalized_identifier`.

#### Scenario: Identifier is normalized before persistence

- **WHEN** an actor submits `  Torre A 101 `
- **THEN** the visible identifier is trimmed
- **AND** `normalized_identifier` stores the canonical slug value (e.g. `torre-a-101`)

#### Scenario: Accented identifier transliterates in normalized value

- **WHEN** an actor submits `Área 4`
- **THEN** the visible identifier is trimmed as submitted
- **AND** `normalized_identifier` is `area-4`

#### Scenario: Equivalent identifiers collide via normalized value

- **GIVEN** section S contains a unit with `identifier: "Area 4"`
- **WHEN** another unit in S is submitted with `identifier: "Área 4"`
- **THEN** creation is rejected with an identifier uniqueness error
- **AND** both map to the same `normalized_identifier`

#### Scenario: Blank normalized identifier is rejected

- **WHEN** identifier normalizes to blank
- **THEN** creation or update is rejected with an identifier error

#### Scenario: Client-supplied normalized identifier is not trusted

- **WHEN** a client submits identifier I and an unrelated normalized value N
- **THEN** the system derives the normalized value from I via `DomainCodes::Slug`
- **AND** N cannot bypass uniqueness

#### Scenario: Import-supplied normalized identifier is not trusted

- **WHEN** a bulk import row includes `normalized_identifier`
- **THEN** the system ignores the imported normalized value
- **AND** derives `normalized_identifier` from the submitted visible identifier

#### Scenario: Search uses canonical normalization

- **WHEN** a user searches an identifier using equivalent case, whitespace or Unicode
- **THEN** the authorized unit can be found through the canonical normalized value

## ADDED Requirements

### Requirement: Unit has a system-derived code column

The system SHALL add a nullable `code` column to `Unit`. On create, the system SHALL always derive `Unit#code` from placement context and the unit's persisted `normalized_identifier` (after `Units::NormalizeIdentifier`). The derivation formula is:

- If a `property_section` with a resolved `code` is present: `{section_code}-{normalized_identifier}`.
- If no section (root-level unit): `{property_code}-{normalized_identifier}`.

Derived codes MUST satisfy the alphanumeric-hyphen format and be unique within `(organization, residential_property, property_section_id)` among non-deleted units. Any client-submitted `code` MUST be stripped. Updating a unit `identifier` after creation MUST NOT automatically update `code`.

#### Scenario: Unit code is derived under a section

- **GIVEN** section S has `code: clp-tor-torre-a-piso-1` and no unit in S
- **WHEN** the first unit is created in S with `identifier: "101"`
- **THEN** the persisted `normalized_identifier` is `101`
- **AND** the persisted `code` is `clp-tor-torre-a-piso-1-101`
- **AND** the persisted `identifier` is `101`

#### Scenario: Accented identifier flows through normalized_identifier into code

- **GIVEN** section S has `code: clp-tor-torre-a-piso-1`
- **WHEN** a unit is created in S with `identifier: "Área 4"`
- **THEN** the persisted `normalized_identifier` is `area-4`
- **AND** the persisted `code` is `clp-tor-torre-a-piso-1-area-4`
- **AND** the persisted `identifier` is `Área 4` (trimmed)

#### Scenario: Code collision receives suffix defensively

- **GIVEN** a unit with `code: clp-tor-torre-a-piso-1-101` already exists in section S due to legacy data or a console correction
- **AND** no unit in S has `normalized_identifier` `101`
- **WHEN** another unit is created in S with `identifier: "101"`
- **THEN** the new unit receives `code: clp-tor-torre-a-piso-1-101-2`

#### Scenario: Client-submitted code is ignored

- **WHEN** a client submits a unit creation request with `code: "CUSTOM-UNIT"` in the request
- **THEN** the persisted `code` is the server-derived value, not `CUSTOM-UNIT`

#### Scenario: Identifier remains user-driven

- **WHEN** a unit is created with `identifier: "4B"` via wizard or bulk import
- **THEN** the persisted `identifier` is `4B` (trimmed)
- **AND** the system derives `normalized_identifier` and `code` from that identifier

#### Scenario: Unit move to another section keeps code intact

- **GIVEN** unit U in section A has `code: clp-tor-torre-a-piso-1-101` and `identifier: "101"`
- **WHEN** U is moved to eligible section B via `Units::MoveToSection`
- **THEN** U references section B
- **AND** U keeps `code: clp-tor-torre-a-piso-1-101`

#### Scenario: Unit identifier change does not change code

- **GIVEN** unit U has `code: clp-tor-torre-a-piso-1-101`
- **WHEN** U's `identifier` is updated through a supported update path
- **THEN** U keeps `code: clp-tor-torre-a-piso-1-101`
