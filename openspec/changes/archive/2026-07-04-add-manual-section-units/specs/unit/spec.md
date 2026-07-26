## ADDED Requirements

### Requirement: Manual wizard unit creation supports individual and multiple modes

The system SHALL allow authorized step 3 users to create units manually from an eligible section using individual or multiple creation modes. Both modes MUST delegate each persisted unit to `Units::Create` and enforce tenant isolation, property scoping, section eligibility, identifier normalization, and uniqueness.

Multiple unit creation SHALL mirror the manual section multiple-creation interaction: the dialog offers "Individual" and "Multiple"; Multiple uses `cantidad`, optional `prefijo`, and `formato` (`letter` or `number`) to generate identifiers; and the dialog shows a live "De creación" preview before persistence. The generated identifier is the unit identifier. Multiple mode inherits the same quantity and suffix-range limits as manual section multiple creation. Shared fields such as `unit_type` and optional `area_m2` apply to every generated unit; `display_name` is not available in the multiple-unit creation dialog and remains blank for generated units.

Multiple creation MUST be all-or-nothing. If any planned unit fails validation, authorization, section eligibility, uniqueness, or persistence, no planned unit from that request SHALL remain persisted and the user SHALL see a descriptive alert explaining that the batch was not created.

#### Scenario: Individual mode creates one unit in selected section

- **GIVEN** an authorized user selects add-unit on eligible section S in draft property P
- **WHEN** they submit valid individual unit data
- **THEN** exactly one unit is persisted through `Units::Create`
- **AND** the unit belongs to P, organization O, and section S

#### Scenario: Multiple mode creates units in selected section

- **GIVEN** an authorized user selects add-unit on eligible section S
- **WHEN** they confirm a valid multiple-unit preview generated from `cantidad`, optional `prefijo`, and `formato`
- **THEN** each unit is persisted through `Units::Create`
- **AND** each unit belongs to S and uses a generated identifier shown in the preview
- **AND** each unit uses the shared submitted `unit_type` and optional `area_m2`

#### Scenario: Multiple mode blocks duplicate identifiers

- **GIVEN** section S already contains a non-deleted unit with normalized identifier `101`
- **WHEN** a multiple creation request includes an equivalent identifier for S
- **THEN** the whole batch is rejected
- **AND** no planned unit from that request remains persisted
- **AND** the user sees a descriptive alert explaining that the batch was not created

#### Scenario: Multiple mode rolls back when one generated unit fails

- **GIVEN** a multiple creation request plans several units
- **AND** one planned unit fails validation or persistence
- **WHEN** the request is processed
- **THEN** no units from that request remain persisted
- **AND** the user sees a descriptive alert with the cause of failure

### Requirement: Manual wizard unit edit is descriptive only

The system SHALL allow authorized step 3 users with `manage_units` permission to edit only descriptive unit fields through the unit edit dialog: `area_m2`, optional `display_name`, `unit_type`, and `identifier`. The update MUST delegate to `Units::Update`.

The edit operation MUST NOT accept property, organization, section placement, status, lifecycle, or client-supplied code changes. Identifier updates SHALL regenerate the server-derived code from the unit's current placement context and updated normalized identifier. If the regenerated code collides with another non-deleted unit code, the identifier modification SHALL be rejected and the existing identifier and code SHALL remain unchanged.

#### Scenario: Edit updates allowed descriptive fields

- **GIVEN** an authorized user edits unit U in draft property P
- **WHEN** they submit valid `area_m2`, `display_name`, `unit_type`, and `identifier`
- **THEN** `Units::Update` persists those descriptive changes
- **AND** U remains in its original property and section context

#### Scenario: Edit rejects placement change

- **GIVEN** unit U belongs to section A
- **WHEN** the edit request submits section B or another placement value
- **THEN** the placement change is ignored or rejected
- **AND** U remains assigned to section A

#### Scenario: Edit regenerates derived code when identifier changes

- **GIVEN** unit U has an existing derived code
- **WHEN** the user changes U's identifier through the edit dialog
- **THEN** the identifier and normalized identifier are validated according to the unit contract
- **AND** U's code is regenerated from U's current section or property context and the updated normalized identifier

#### Scenario: Edit rejects identifier change when regenerated code collides

- **GIVEN** unit U would regenerate code `clp-tor-torre-a-piso-1-102` after changing its identifier
- **AND** another non-deleted unit already uses code `clp-tor-torre-a-piso-1-102` in the same placement context
- **WHEN** the user submits the identifier change
- **THEN** the update is rejected with a code or identifier error
- **AND** U keeps its previous identifier, normalized identifier, and code

### Requirement: Manual wizard unit deletion soft-deletes units

The system SHALL delete units from step 3 manual management through an explicit soft-delete operation. The operation MUST require `manage_units`, tenant/property scoping, and confirmation in the UI before the request is sent. The confirmation dialog SHALL always include a generic warning that soft-deleting a unit preserves existing related records such as ownerships, occupancies, leases, visits, and audit history. Existing related records SHALL NOT block the soft delete.

Soft-deleted units SHALL be omitted from the step 3 preview and SHALL release their identifier context according to the existing soft-delete uniqueness contract.

#### Scenario: Confirmed delete soft-deletes unit

- **GIVEN** an authorized user confirms deletion of unit U in draft property P
- **WHEN** the delete request is processed
- **THEN** U is soft-deleted through the supported unit lifecycle operation
- **AND** U no longer appears in the step 3 preview

#### Scenario: Delete without confirmation sends no request

- **GIVEN** the delete confirmation dialog for unit U is open
- **WHEN** the user cancels or closes the dialog
- **THEN** no delete request is sent
- **AND** U remains non-deleted

#### Scenario: Delete confirmation warns about related records

- **GIVEN** the delete confirmation dialog for unit U is open
- **WHEN** the dialog renders
- **THEN** it warns that related records and history are preserved
- **AND** it explains that the unit will disappear from the setup preview after confirmation

#### Scenario: Soft-deleted unit releases identifier context

- **GIVEN** unit U in section S is soft-deleted
- **WHEN** an authorized user creates another unit in S with U's former identifier
- **THEN** creation may succeed if all other unit rules pass

#### Scenario: User with manage_units may manage draft units

- **GIVEN** a user has `manage_units` for draft property P
- **WHEN** they create, edit, or soft-delete a unit through the setup wizard
- **THEN** the operation is authorized for that draft unit context

#### Scenario: User without manage_units is denied

- **GIVEN** a user lacks `manage_units` for draft property P
- **WHEN** they attempt to delete unit U from P through the setup wizard
- **THEN** authorization is denied
- **AND** U remains non-deleted

## MODIFIED Requirements

### Requirement: Unit has a system-derived code column

The system SHALL add a nullable `code` column to `Unit`. On create, the system SHALL always derive `Unit#code` from placement context and the unit's persisted `normalized_identifier` (after `Units::NormalizeIdentifier`). The derivation formula is:

- If a `property_section` with a resolved `code` is present: `{section_code}-{normalized_identifier}`.
- If no section (root-level unit): `{property_code}-{normalized_identifier}`.

Derived codes MUST satisfy the alphanumeric-hyphen format and be unique within `(organization, residential_property, property_section_id)` among non-deleted units. Any client-submitted `code` MUST be stripped. Updating a unit `identifier` through a supported descriptive update path SHALL regenerate `code` from the unit's current placement context and updated persisted `normalized_identifier`. If the regenerated code collides with another non-deleted unit code, the identifier update MUST be rejected and the unit MUST keep its previous identifier, normalized identifier, and code. Updating placement through `Units::MoveToSection` SHALL keep code intact unless that operation explicitly defines a code-regeneration behavior in a later contract.

#### Scenario: Unit code is derived under a section

- **GIVEN** section S has `code: clp-tor-torre-a-piso-1` and no unit in S with `normalized_identifier` `101`
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

#### Scenario: Unit identifier change regenerates code

- **GIVEN** unit U has `code: clp-tor-torre-a-piso-1-101` and belongs to section S with `code: clp-tor-torre-a-piso-1`
- **WHEN** U's `identifier` is updated to `"102"` through a supported update path
- **THEN** U's `normalized_identifier` is updated to `102`
- **AND** U's `code` is regenerated as `clp-tor-torre-a-piso-1-102`

#### Scenario: Unit identifier change rejects code collision

- **GIVEN** unit U has `code: clp-tor-torre-a-piso-1-101`
- **AND** another non-deleted unit already has `code: clp-tor-torre-a-piso-1-102`
- **WHEN** U's `identifier` is updated to `"102"` through a supported update path
- **THEN** the update is rejected with a controlled error
- **AND** U keeps `identifier: "101"` and `code: clp-tor-torre-a-piso-1-101`
