## ADDED Requirements

### Requirement: Draft-phase section removal via soft delete

During the setup wizard (draft property), the system SHALL allow removal of a section that has no children and no units through `PropertySections::Destroy`. This use case performs a paranoia soft delete (`section.destroy`) rather than `Archive`, so the section disappears from the default scope and the live preview reflects the removal immediately.

`PropertySections::Destroy` is only valid while the property is in `draft` status. It MUST be authorized through the setup/manage-sections capability (`authorize_setup_property!`) and scoped to the current property and organization. The existing `dependent: :restrict_with_error` on `children` and `units` governs what can be deleted: a section with dependents fails cleanly and the error is surfaced to the user.

`Archive` remains the supported lifecycle operation for the ordinary non-wizard admin flow. `Destroy` is additive and applies only during draft construction.

#### Scenario: Empty leaf section is soft-deleted during setup

- **GIVEN** a draft property with a section that has no children and no units
- **WHEN** an authorized user confirms deletion in the wizard
- **THEN** `PropertySections::Destroy` soft-deletes the section via paranoia
- **AND** the section disappears from the live structure preview
- **AND** the audit trail is preserved via `deleted_at`

#### Scenario: Destroy is blocked when dependents exist

- **GIVEN** a section that has child sections or units
- **WHEN** `PropertySections::Destroy` is called
- **THEN** the operation is rejected due to `dependent: :restrict_with_error`
- **AND** a clear error is returned and no record is deleted

#### Scenario: Destroy requires draft property status

- **GIVEN** a property that is not in `draft` status
- **WHEN** `PropertySections::Destroy` is invoked on one of its sections
- **THEN** the operation is rejected with a property lifecycle error
- **AND** the section remains intact

#### Scenario: Soft-deleted section does not conflict on re-create

- **GIVEN** a section was soft-deleted via `Destroy`
- **WHEN** a new section with the same name and parent is created
- **THEN** creation succeeds because the unique index is scoped `WHERE deleted_at IS NULL`
- **AND** no uniqueness error is raised for the removed section
