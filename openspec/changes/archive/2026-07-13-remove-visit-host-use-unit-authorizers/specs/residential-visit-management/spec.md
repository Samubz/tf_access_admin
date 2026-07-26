## MODIFIED Requirements

### Requirement: Resident and visitor references preserve Person and User semantics

The system SHALL use `Person` references for visitor identity and `User` references for authenticated action actors. This flow SHALL NOT persist a host person.

#### Scenario: Resident visit records identity and actors

- **GIVEN** authenticated user R is authorized to register a visit for unit U
- **WHEN** the visit is created successfully
- **THEN** `visitor_person_id` references the resolved visitor `Person`
- **AND** `created_by_id` references user R
- **AND** `authorized_by_id` references user R
- **AND** neither actor column references a `Person`

### Requirement: Visit location is derived from the resident unit

The system SHALL derive visit organization, residential property, and optional property section from the authenticated context and submitted `unit_id`. Client-supplied organization, property, section, actor, or status values SHALL NOT override backend resolution.

#### Scenario: Location is derived consistently

- **GIVEN** unit U belongs to property P and optional section S in organization O
- **WHEN** an authorized resident creates a visit for U
- **THEN** the visit stores O, P, S, and U consistently
- **AND** `residential_property_id` and `property_section_id` are derived from U

#### Scenario: Client cannot force another property

- **GIVEN** the resident is authorized for unit U in property P
- **WHEN** the request includes or attempts to imply property Q
- **THEN** the system ignores or rejects the untrusted property value
- **AND** no visit is created in Q
