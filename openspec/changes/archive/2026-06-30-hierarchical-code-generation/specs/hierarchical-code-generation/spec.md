# hierarchical-code-generation Specification

## Purpose

Defines canonical rules for deriving stable alphanumeric `code` values from hierarchy, entity type, and source labels across residential properties, property sections, and units. Property and section codes use entity `name`; unit codes use `normalized_identifier` (canonical slug of the human-facing `identifier`). Codes are system-managed; users do not set or edit them via UI.

## ADDED Requirements

### Requirement: Code slugs are derived via DomainCodes::Slug without parsing

The system SHALL build code segments using `DomainCodes::Slug`: transliteration, lowercase, whitespace-to-hyphen conversion, and removal of characters outside `[a-zA-Z0-9-]`. For properties and sections the input is `name`; for units the persisted `normalized_identifier` (itself derived via `DomainCodes::Slug` from `identifier`) is the segment appended to the hierarchy prefix. The system MUST NOT parse numeric or letter suffixes from existing names, identifiers, or codes to infer the next value.

#### Scenario: Accented name produces ASCII slug

- **WHEN** a property or section display name `Torre Á` is slugged for code derivation
- **THEN** the slug segment is `torre-a`

#### Scenario: Accented identifier produces ASCII normalized value used in unit code

- **WHEN** a unit is created with `identifier: "Área 4"`
- **THEN** `normalized_identifier` is `area-4`
- **AND** the unit code segment appended to the section prefix is `area-4`

#### Scenario: Non-sequential label is slugged literally

- **WHEN** a display name or identifier `Torre 123` is slugged
- **THEN** the slug segment is `torre-123`
- **AND** the system does not treat `123` as a sequence cursor for other names or identifiers

### Requirement: Type abbreviations are stable per catalog value

The system SHALL map each canonical `property_type` and `section_type` to a fixed lowercase alphanumeric abbreviation used in derived codes.

#### Scenario: Known section type maps to abbrev

- **WHEN** `section_type` is `tower`
- **THEN** the type abbreviation used in root section codes is `tor`

### Requirement: Collision resolution uses numeric suffix in scope

When a derived code candidate already exists in the relevant uniqueness scope among non-deleted records, the system SHALL append `-2`, `-3`, … until a free code is found.

#### Scenario: Duplicate derived code gets suffix

- **GIVEN** section code `cdo-tor-torre-a` already exists in the same uniqueness context
- **WHEN** another section would derive the same base code
- **THEN** the system assigns `cdo-tor-torre-a-2`

### Requirement: Codes are system-derived and not user-editable via UI

The system SHALL always derive `code` on create for residential properties, property sections, and units. The system MUST strip any client-submitted `code` value on user-facing paths. No user-facing form SHALL expose a `code` input. Override is only permitted via internal tooling (console).

Codes are derived from creation-time hierarchy and source labels, then remain stable. Later changes to property name, section name, unit identifier, or unit section placement MUST NOT automatically update existing codes.

#### Scenario: Client-submitted code is ignored on create

- **WHEN** a client submits a property creation request with `code: "CUSTOM"`
- **THEN** the persisted code is the server-derived value, not `CUSTOM`

#### Scenario: No code input in section creation form

- **WHEN** the user opens the section creation modal
- **THEN** no `code` field is visible or submittable

#### Scenario: Console override is possible

- **WHEN** an operator runs `update_column(:code, "CORRECTED")` directly in Rails console
- **THEN** the record is updated with the provided value
- **AND** no UI path enables this operation

#### Scenario: Existing code remains stable after source or placement changes

- **GIVEN** a record already has a derived `code`
- **WHEN** its name, identifier, or unit section placement changes through a supported update path
- **THEN** the existing `code` remains unchanged

#### Scenario: Unit section move keeps code intact

- **GIVEN** unit U has `code: clp-tor-torre-a-piso-1-101`
- **WHEN** U is moved to another section via `Units::MoveToSection`
- **THEN** U keeps `code: clp-tor-torre-a-piso-1-101`
