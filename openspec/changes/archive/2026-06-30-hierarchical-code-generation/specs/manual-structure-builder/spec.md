# manual-structure-builder Delta Specification

## MODIFIED Requirements

### Requirement: Section creation supports individual and multiple modes

The creation modal SHALL offer two modes, "Individual" and "Múltiple". Individual creates a single section; Múltiple generates a batch under one parent context from a `cantidad`, an optional `prefijo`, and a naming `formato` (letter `A, B, C…` or numeric `1, 2, 3…`). Section codes are assigned automatically by the backend; the modal MUST NOT expose a code input. The modal SHALL show a live "De creación" preview of the names that will be generated.

The add-root modal creates root sections; the add-child modal is bound to a fixed parent root section and SHALL create only child sections under it. Batch creation MUST respect the two-level limit and unit-placement rules and SHALL persist through the existing section creation path; child batches MUST NOT create a third level.

#### Scenario: Multiple mode generates a named batch

- **GIVEN** the add-root modal in "Múltiple" mode
- **WHEN** the user sets a type, a cantidad, a prefijo, and a letter or numeric naming format
- **THEN** the "De creación" preview lists the resulting names (e.g., "Torre A, Torre B")
- **AND** confirming creates the batch of root sections and the live preview updates
- **AND** each section receives a server-derived code

#### Scenario: Child modal is scoped to its parent root

- **GIVEN** the user chose "Agregar sección hija" on a root section
- **WHEN** the add-child modal opens
- **THEN** it shows the fixed parent ("Sección padre: Torre A") and the sections are created under that root
- **AND** the modal communicates that child sections cannot themselves have children

#### Scenario: Individual mode creates a single section

- **GIVEN** the creation modal in "Individual" mode
- **WHEN** the user provides a name and type and confirms
- **THEN** exactly one section is created in the corresponding context (root or under the fixed parent)
- **AND** the section receives a server-derived code

#### Scenario: No code input in creation or edit modal

- **WHEN** the user opens the add-section or edit-section modal
- **THEN** no `code` field is visible or submittable
