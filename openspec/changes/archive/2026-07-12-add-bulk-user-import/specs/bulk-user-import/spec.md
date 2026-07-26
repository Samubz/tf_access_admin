## ADDED Requirements

### Requirement: Bulk user import wizard
The system SHALL provide an admin bulk import drawer in `/admin/people` for creating organization people from spreadsheet or CSV files. The drawer SHALL follow the existing bulk import flow: upload, configure, preview, confirm, progress, and report.

#### Scenario: Admin starts a bulk user import
- **GIVEN** an authorized admin is viewing `/admin/people`
- **WHEN** the admin opens the bulk import drawer
- **THEN** the system displays the bulk import drawer at the method step
- **AND** accepts `.xlsx`, `.xls`, and `.csv` files

#### Scenario: Uploaded file advances to configuration
- **GIVEN** an authorized admin selected a supported file
- **WHEN** the admin uploads the file
- **THEN** the system creates a `BulkImport` with `import_type` for users
- **AND** the import is scoped to the current organization
- **AND** the wizard advances to the configure step with detected sheets and columns

#### Scenario: Unsupported file is rejected
- **GIVEN** an authorized admin selected an unsupported file
- **WHEN** the admin uploads the file
- **THEN** the system rejects the upload
- **AND** the wizard displays a translated error without creating import rows

### Requirement: Required user fields and column mapping
The system SHALL require every imported person row to map first name, last name, document, phone, email, and birthdate fields. Birthdate values MUST use `DD/MM/YYYY` format. Phone MUST be present but SHALL NOT be format-validated in this version.

#### Scenario: Required columns are detected
- **GIVEN** the uploaded file contains headers for name, last name, document, phone, email, and birthdate
- **WHEN** the configure step loads column mappings
- **THEN** the system marks all required target fields as matched
- **AND** the admin can continue to preview

#### Scenario: Required column is missing
- **GIVEN** the uploaded file does not include a mappable required header
- **WHEN** the configure step loads column mappings
- **THEN** the system marks the missing target field as required and unmatched
- **AND** the admin cannot continue to preview until the file or sheet is corrected

#### Scenario: Birthdate format rule is visible
- **WHEN** the configure step displays validation rules
- **THEN** the system states that birthdate must be entered as `DD/MM/YYYY` or `DD-MM-YYYY`

### Requirement: Row validation before import
The system SHALL validate every parsed row before confirmation and SHALL store normalized payload, raw payload, validation status, row errors, and row warnings per `BulkImportRow`.

#### Scenario: Valid row passes preview
- **GIVEN** a row has all required fields
- **AND** email has a valid format
- **AND** birthdate is a real calendar date in `DD/MM/YYYY` format
- **AND** document and email do not conflict in the file or organization
- **WHEN** the import is validated
- **THEN** the row is marked valid
- **AND** the preview counts it as importable

#### Scenario: Missing required value is an error
- **GIVEN** a row has a blank required field
- **WHEN** the import is validated
- **THEN** the row is marked error
- **AND** the error identifies the missing field

#### Scenario: Phone format is not validated
- **GIVEN** a row has a non-blank phone value in an unexpected format
- **WHEN** the import is validated
- **THEN** the row is not marked error because of phone format

#### Scenario: Invalid email is an error
- **GIVEN** a row has an email that is not a valid email address
- **WHEN** the import is validated
- **THEN** the row is marked error
- **AND** the error identifies the email field

#### Scenario: Invalid birthdate format is an error
- **GIVEN** a row has birthdate `1990-12-31`
- **WHEN** the import is validated
- **THEN** the row is marked error
- **AND** the error identifies the birthdate format requirement

#### Scenario: Birthdate with hyphen separator is accepted
- **GIVEN** a row has birthdate `31-12-1990`
- **WHEN** the import is validated
- **THEN** the row is marked valid
- **AND** the birthdate is stored as `1990-12-31` (ISO format)

#### Scenario: Impossible birthdate is an error
- **GIVEN** a row has birthdate `31/02/1990`
- **WHEN** the import is validated
- **THEN** the row is marked error
- **AND** the system does not coerce it to another date

#### Scenario: Future birthdate is an error
- **GIVEN** a row has a birthdate after the current date
- **WHEN** the import is validated
- **THEN** the row is marked error
- **AND** the error identifies the birthdate field

#### Scenario: Duplicate document in file is detected
- **GIVEN** two rows in the file normalize to the same document
- **WHEN** the import is validated
- **THEN** duplicate rows are marked as duplicate or error according to the selected import mode
- **AND** the preview identifies the document conflict

#### Scenario: Duplicate email in file is detected
- **GIVEN** two rows in the file normalize to the same email
- **WHEN** the import is validated
- **THEN** duplicate rows are marked as duplicate or error according to the selected import mode
- **AND** the preview identifies the email conflict

#### Scenario: Existing organization identity is detected
- **GIVEN** a row document or email matches an active `Person` in the current organization
- **WHEN** the import is validated
- **THEN** the row is marked duplicate or error according to the selected import mode
- **AND** the preview identifies the existing identity conflict

#### Scenario: Cross-organization identity does not conflict
- **GIVEN** a row document or email exists only in another organization
- **WHEN** the import is validated
- **THEN** the row is not marked duplicate for that reason

### Requirement: Preview and confirmation controls
The system SHALL display a paginated preview inside the `/admin/people` drawer with summary counts, filters, search, row-level results, and controls matching the bulk units import drawer semantics.

#### Scenario: Preview summarizes row statuses
- **GIVEN** validation completed
- **WHEN** the preview step renders
- **THEN** the system shows total, valid, warning or duplicate, and error counts
- **AND** the row table shows row number, user identity fields, validation status, and primary issue

#### Scenario: Rows can be filtered and searched
- **GIVEN** validation completed
- **WHEN** the admin filters by status or searches by name, document, email, or phone
- **THEN** the preview table displays matching rows within the current organization import

#### Scenario: Import with errors requires valid rows only
- **GIVEN** preview contains one or more error rows
- **WHEN** the admin proceeds to confirmation
- **THEN** the system enables the valid-rows-only option by default
- **AND** the system prevents importing error rows

#### Scenario: Import cannot proceed with no importable rows
- **GIVEN** every row is an error or skipped duplicate
- **WHEN** the admin reaches the import step
- **THEN** the confirm action is disabled

### Requirement: Bulk user import execution
The system SHALL create `Person` records only for importable rows when the admin confirms the import. A per-row failure MUST NOT stop the remaining rows.

#### Scenario: Confirmed import creates people
- **GIVEN** a validated import has importable rows
- **WHEN** the admin confirms the import
- **THEN** the system processes rows asynchronously or through the existing bulk import execution boundary
- **AND** creates one active natural `Person` record in the `people` table per imported row in the current organization
- **AND** stores first name, last name, document, phone, email, and birthdate on the person using existing person identity/contact conventions

#### Scenario: Row failure does not abort the batch
- **GIVEN** one importable row fails during creation
- **WHEN** the import is processing
- **THEN** the row is marked failed with a translated failure message
- **AND** later importable rows continue processing
- **AND** the final import status reflects completed with errors when any row failed

#### Scenario: Duplicate rows are skipped when configured
- **GIVEN** the selected mode skips duplicates
- **WHEN** a row duplicates a file row or existing organization person
- **THEN** the row is not imported
- **AND** it contributes to skipped counts

#### Scenario: Report includes validation and import outcomes
- **GIVEN** an import has completed or completed with errors
- **WHEN** the admin downloads the report
- **THEN** the report includes row number, submitted identity fields, validation status, import status, and issue messages

### Requirement: Authorization and tenant isolation
The system SHALL authorize every bulk user import action with capability-based policies and SHALL scope every query, row, file, and created person to the current organization.

#### Scenario: Unauthorized user cannot import users
- **GIVEN** a user lacks permission to manage people/users
- **WHEN** the user attempts to upload, validate, confirm, poll, list rows, or download a report
- **THEN** the system denies access

#### Scenario: Import cannot access another organization's bulk import
- **GIVEN** a bulk import belongs to another organization
- **WHEN** an admin from the current organization requests it by id
- **THEN** the system responds as not found or forbidden without leaking row data
