## MODIFIED Requirements

### Requirement: Step 2 defines optional property structure
Step 2 SHALL let the user choose how the property internal structure will be defined. The available structure modes and form fields SHALL be derived from the `property_type` selected in step 1.

The user MUST be able to choose exactly one of:

1. no sections;
2. manual hierarchical structure (guided by the recommended format);
3. quick repetitive structure generation (form fields determined by the active format).

The wizard SHALL load the recommended `PropertyStructureFormat` for the `property_type` and pass it to step 2 as a prop. The format defines up to 2 section levels and the target level for units (`units_in`).

#### Scenario: No sections skips hierarchical structure
- **GIVEN** the user selects "Sin secciones"
- **WHEN** they continue
- **THEN** the wizard records that units will belong only to the property
- **AND** step 3 does not require section placement for generated units

#### Scenario: Manual structure allows hierarchical sections with format guidance
- **GIVEN** the user selects "Crear estructura manual"
- **WHEN** they add sections and nested sections
- **THEN** each section is persisted via `PropertySections::Create` on the draft property and shown in the workspace
- **AND** the wizard shows a warning when the created `section_type` does not match the recommended format for the `property_type`
- **AND** the user may edit or remove sections before continuing

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
