# property-section Delta Specification

## ADDED Requirements

### Requirement: Property section code is always system-derived

The system SHALL always derive `PropertySection#code` on create. Root sections MUST incorporate the residential property code (derived in-memory if the property is unsaved), the section `section_type` abbreviation, and a slug of the section `name`. Child sections MUST incorporate the parent section code and a slug of the child `name`. Derived codes MUST satisfy the alphanumeric-hyphen format and uniqueness within `(organization, residential_property, parent_id, section_type)`. Any client-submitted `code` MUST be stripped and replaced by the derived value.

#### Scenario: Root section code is derived

- **GIVEN** property P has `code: clp` and no root section with code `clp-tor-torre-a`
- **WHEN** a root section is created with `name: "Torre A"` and `section_type: tower`
- **THEN** the persisted `code` is `clp-tor-torre-a`

#### Scenario: Child section code extends parent code

- **GIVEN** parent section S has `code: clp-tor-torre-a`
- **WHEN** a child is created under S with `name: "Piso 1"`
- **THEN** the persisted `code` is `clp-tor-torre-a-piso-1`

#### Scenario: Section code collision in same context receives suffix

- **GIVEN** a child section already exists with `code: clp-tor-torre-a-piso-1` under the same parent and `section_type` due to legacy data or a console correction
- **WHEN** another child derives the same base code without violating section name uniqueness
- **THEN** the new section receives `code: clp-tor-torre-a-piso-1-2`

#### Scenario: Client-submitted code is ignored

- **WHEN** a section is created via a user-facing path with `code: "CUSTOM-SEC"` in the request
- **THEN** the persisted `code` is the server-derived value, not `CUSTOM-SEC`

#### Scenario: Batch create derives code per section

- **WHEN** multiple sections are created in one batch
- **THEN** each persisted section receives its own derived code based on its own `name` and placement context

#### Scenario: Section rename or move does not change code

- **GIVEN** section S has `code: clp-tor-torre-a-piso-1`
- **WHEN** S is renamed or moved through a supported update path
- **THEN** S keeps `code: clp-tor-torre-a-piso-1`
