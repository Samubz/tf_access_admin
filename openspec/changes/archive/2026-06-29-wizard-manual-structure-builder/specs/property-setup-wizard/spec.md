## MODIFIED Requirements

### Requirement: Step 2 defines optional property structure

Step 2 SHALL let the user choose how the property internal structure will be defined. The available structure modes and form fields SHALL be derived from the `property_type` selected in step 1.

The user MUST be able to choose exactly one of:

1. no sections;
2. manual hierarchical structure (a free-form builder constrained to the two-level model, guided by the recommended format);
3. quick repetitive structure generation (form fields determined by the active format).

In manual mode the wizard SHALL provide a full structure builder that lets the user create, rename, and delete sections, choose each section's type and parent, and see the tree update live in the shared preview panel. The builder SHALL enforce the existing hierarchy rules (max two levels; a section with children cannot hold units; units attach only to leaf sections) by delegating to `PropertySections::Create` and the section-removal use case, surfacing model validation errors rather than bypassing them.

The wizard SHALL load the recommended `PropertyStructureFormat` for the `property_type` and pass it to step 2 as a prop. The format defines up to 2 section levels and the target level for units (`units_in`).

#### Scenario: No sections skips hierarchical structure

- **GIVEN** the user selects "Sin secciones"
- **WHEN** they continue
- **THEN** the wizard records that units will belong only to the property
- **AND** step 3 does not require section placement for generated units

#### Scenario: Manual structure builder creates, edits, and removes sections

- **GIVEN** the user selects "Crear estructura manual"
- **WHEN** they add root sections and child sections
- **THEN** each section is persisted via `PropertySections::Create` on the draft property and shown in the live preview
- **AND** the wizard shows a warning when the created `section_type` does not match the recommended format for the `property_type`
- **AND** the user may rename or delete sections before continuing, with deletions guarded by the existing dependent-section/unit rules

#### Scenario: Manual builder rejects a third hierarchy level

- **GIVEN** a root section that already has a child section
- **WHEN** the user attempts to add a section under that child
- **THEN** the operation is rejected with the two-level validation message
- **AND** the persisted structure is unchanged

#### Scenario: Quick structure form adapts to active format

- **GIVEN** the user selects "Crear estructura rápida"
- **WHEN** the active format has 2 levels (e.g., tower/floor)
- **THEN** the form shows inputs for level 1 count, level 2 count per level 1, and prefix for each level
- **AND** when the active format has 1 level (e.g., floor-only or block-only), the form shows only count and prefix for that level
- **AND** the quick mode option is not shown when the property type has no mapped format

#### Scenario: Quick structure preview must be confirmed before continuing

- **GIVEN** the user configures quick structure parameters
- **WHEN** the preview is shown
- **THEN** the user can review the sections that will be created, including names and hierarchy
- **AND** the preview shows counts and detects duplicates or conflicts with existing sections
- **AND** the user must confirm the generated structure before advancing

#### Scenario: building allows removing the tower level

- **GIVEN** the `property_type` is `building` and step 2 shows the tower/floor format
- **WHEN** the user disables the "¿El edificio tiene torres?" toggle
- **THEN** the active format switches to floor-only
- **AND** the quick structure form adapts to show only floor count and prefix

#### Scenario: Structure step shows preview panel in all modes

- **GIVEN** the user is in step 2 in any mode (none, manual, or quick)
- **WHEN** the step renders
- **THEN** a preview panel is always visible showing the current structure state
- **AND** in none mode it shows an empty state; in manual mode it reflects persisted sections live; in quick mode it shows the in-memory generated batch
- **AND** the panel renders sections only — units are not present in step 2 and the panel handles their absence without error

#### Scenario: Step 3 reuses the same preview panel with units

- **GIVEN** the user is in step 3 in automatic generation mode
- **WHEN** a unit batch has been generated in memory
- **THEN** the same preview panel component renders sections and units nested under their leaf section
- **AND** when no units have been generated yet the panel shows only sections

#### Scenario: Empty manual structure blocks continuation

- **GIVEN** the user chose manual structure
- **WHEN** no section has been added
- **THEN** continuation is blocked
- **AND** an empty-state message explains that structure is required for this option

#### Scenario: Changing property_type in step 1 resets step 2 format

- **GIVEN** the user configured step 2 with a structure
- **WHEN** the user navigates back to step 1 and changes `property_type`
- **THEN** the active format in step 2 is recalculated for the new type
- **AND** previously configured structure values are discarded
- **AND** a notice informs the user that the structure configuration was reset

### Requirement: Step 3 defines how units will be created

Step 3 SHALL let the user choose how units for the property will be created and persisted during this step.

Supported modes:

1. create a single unit;
2. create multiple units automatically, using the structure from step 2 — available **only** when step 2 used quick mode;
3. import units from Excel through the existing bulk import flow.

Automatic generation is gated to quick mode: when step 2 was manual or none, the automatic option SHALL NOT be offered and the user is directed to single creation or import. When quick mode was used, automatic generation applies the established identifier-format rules (`floor_sequential` / `block_sequential` / `sequential`, `units_per_leaf`) derived from the active `PropertyStructureFormat` (`units_in`).

The step MUST show contextual information from previous steps, including property name and structure summary when available.

#### Scenario: Automatic generation is available only for quick structures

- **GIVEN** step 2 used quick mode and produced a hierarchical structure
- **WHEN** the user opens step 3
- **THEN** they may choose to generate units automatically from that structure
- **AND** configuration fields such as unit type, identifier format, and units per leaf are available
- **AND** a live preview shows sample generated unit identifiers

#### Scenario: Automatic generation is unavailable for manual and none modes

- **GIVEN** step 2 used manual or none mode
- **WHEN** the user opens step 3
- **THEN** the automatic generation mode is not offered
- **AND** the user is directed to single creation or import

#### Scenario: Single unit creation is available for simple cases

- **GIVEN** the user chooses individual unit creation
- **WHEN** they provide valid unit data
- **THEN** the unit is persisted via `Units::Create` on the draft property
- **AND** the unit is associated with the draft property and optional section

#### Scenario: Excel import reuses existing bulk import behavior

- **GIVEN** the user chooses import from Excel
- **WHEN** they upload or select a file through the wizard
- **THEN** validation and parsing reuse the existing bulk import contract for units
- **AND** the wizard surfaces import errors, warnings and duplicates without duplicating domain rules in the client

#### Scenario: Unit step shows estimated creation summary

- **GIVEN** the user configured unit generation for 80 units
- **WHEN** the auxiliary summary renders
- **THEN** it states how many units will be created
- **AND** it explains the calculation basis when generation is automatic

#### Scenario: Unit validation errors are shown without losing wizard state

- **GIVEN** one or more units or import rows are invalid
- **WHEN** the user attempts to continue
- **THEN** the wizard remains on step 3
- **AND** errors, warnings or duplicates are shown per item or row
- **AND** previously persisted units and setup data remain intact
