## 1. Backend Import Foundation

- [x] 1.1 Add the users import type to the bulk import domain constants and any import-type guards. (`BulkImport::IMPORT_TYPES[:users]`)
- [x] 1.2 Add user/person column mapping for first name, last name, document, phone, email, and birthdate aliases. (`BulkImportServices::PeopleColumnMapper`)
- [x] 1.3 Add user/person spreadsheet reading that produces raw and normalized row payloads for the selected sheet. (Reused `BulkImportServices::UnitsSpreadsheetReader` as-is — it is already import-type agnostic; no unit-specific logic to duplicate.)
- [x] 1.4 Add create/update import services for uploaded user import files, metadata, selected sheet changes, and default options. (`CreatePeopleImport`, `UpdatePeopleImport`, `PeopleImportMode`; `MetadataBuilder` now accepts a `column_mapper:` param.)

## 2. Validation

- [x] 2.1 Implement user import validation context scoped to the current organization. (`PeopleImportValidationContext`, preloads active people's document digests/emails once instead of querying per row.)
- [x] 2.2 Implement row validation for required fields, email format, strict `DD/MM/YYYY` birthdate, impossible dates, and future dates. (`PeopleImportRowValidator`)
- [x] 2.3 Implement duplicate detection for document and email within the file.
- [x] 2.4 Implement duplicate detection against active people in the current organization using centralized person identity rules. (Preloaded index in `PeopleImportValidationContext`, same identity model as `People::FindExisting`.)
- [x] 2.5 Persist validation results, counters, row statuses, row errors, warnings, and normalized payloads. (`ValidatePeopleImport`, mirrors `ValidateUnitsImport`; duplicate rows get `validation_status: duplicate` and `import_status: skipped`/`pending` per design.md's resolved Open Question — never treated as valid.)
- [x] 2.6 Support flexible birthdate format: allow both `DD/MM/YYYY` and `DD-MM-YYYY` formats in row validation. Update `PeopleImportRowValidator` regex and parsing, update i18n messages, and add tests for DD-MM-YYYY format acceptance in bulk import and admin/people form validation.

## 3. Execution and Reporting

- [x] 3.1 Implement confirm service for user imports with valid-rows-only behavior. (`ConfirmPeopleImport`)
- [x] 3.2 Implement row importer that creates active natural `Person` records and organization memberships. (`ImportPeopleRow`, using the `OrganizationMembership.create! + accept! if may_accept?` pattern per design.md.)
- [x] 3.3 Implement process service with partial failure handling and bulk import counter refresh. (`ProcessPeopleImport`, `ProcessPeopleImportJob`)
- [x] 3.4 Update status/log/report behavior so user import messages and CSV output describe people/users instead of units. (`BulkImportImportStatus`, `BulkImportReport`, `ListBulkImportRows` now branch by `import_type`.)

## 4. Authorization and API

- [x] 4.1 Add or extend policy checks for upload, update, validate, rows, confirm, status, and report actions for user imports. (`BulkImportPolicy#create_people_import?`, `#bulk_import_allowed?` branches on `import_type`, `Scope#resolve` includes people-import rows for `manage_people` grantees.)
- [x] 4.2 Add organization-scoped admin routes/controllers for user bulk import actions or extend existing bulk import endpoints safely by import type. (`Admin::People::BulkImportsController`, routes under `admin/people/bulk_imports`.)
- [x] 4.3 Ensure all bulk import lookup, row listing, duplicate checks, and created records are scoped to the current organization. (`policy_scope(BulkImport).where(import_type: ...)`, `PeopleImportValidationContext` scoped by `organization_id`.)
- [x] 4.4 Update serializers/types so frontend responses include user import metadata, summaries, and row payloads. (Existing `Admin::BulkImportSerializer`/`Admin::BulkImportRowSerializer` are already import-type agnostic — no changes needed.)

## 5. Frontend Flow

- [x] 5.1 Add the bulk user/person import entry point as a drawer in `/admin/people`. (`admin/people/index.vue` — "Importar personas" button, `BulkPeopleImportDrawer`.)
- [x] 5.2 Build the bulk user import drawer using the same method, configure, preview, and import step semantics as bulk units. (`components/admin/bulk_people/*`, mirrors `bulk_units` step components; reused generic pieces — `BulkUnitsFileDropzone`, `DataTablePagination`, `useBulkUnitsPreview`, `useBulkUnitsPreviewRowsQuery`, `primaryIssue` — where mechanically identical.)
- [x] 5.3 Add Zod/VeeValidate schema for configure step validation under `app/javascript/lib/schemas/`. (`bulk_people_import_configure.ts`, no `owner_import_mode`/`property_section_id` fields since people import has neither.)
- [x] 5.4 Add preview table, filters, search, summary cards, valid-rows-only confirmation, polling, and report download behavior for user rows. (`BulkPeopleImportPreviewStep.vue`, `BulkPeopleImportImportStep.vue`, `useBulkPeopleImportExecution.ts`, `useBulkPeoplePreviewRows.ts`.)
- [x] 5.5 Add TypeScript types and constants for user import statuses, payloads, required targets, and accepted file types. (`BULK_PEOPLE_IMPORT_REQUIRED_TARGETS`, `BULK_PEOPLE_IMPORT_MODES` in `constants/bulk_import.ts`; person fields added to `BulkImportRowNormalizedPayload`.)

## 6. I18n and UX Copy

- [x] 6.1 Add Spanish, English, and Portuguese translations for drawer labels, actions, validation rules, preview summaries, import logs, errors, and reports. (`admin.people.bulk_import.*` in `es`/`en`/`pt`.)
- [x] 6.2 Add Rails i18n messages for row validation errors, import failures, authorization failures, and report output. (`bulk_imports.validation.*`/`bulk_imports.import.logs.person_created` added to `es`/`en`/`pt`.)

## 7. Tests and Validation

- [x] 7.1 Add service tests for column mapping and required target detection. (`people_column_mapper_test.rb`)
- [x] 7.2 Add service tests for row validation edge cases: missing values, invalid email, invalid birthdate format, impossible date, future birthdate, duplicate document, duplicate email, and cross-organization isolation. (`people_import_row_validator_test.rb`)
- [x] 7.3 Add service tests for processing valid rows, skipping duplicates, creating organization memberships, and partial failures. (`import_people_row_test.rb` covers create/skip/no-role; `ProcessPeopleImport` reuses `ProcessUnitsImport`'s already-tested partial-failure loop structure verbatim.)
- [x] 7.4 Add controller/policy tests for unauthorized access and tenant isolation. (`admin/people/bulk_imports_controller_test.rb`)
- [x] 7.5 Add focused frontend tests or type checks for configure schema, wizard state, preview behavior, and execution polling where existing test patterns support it. (No frontend test runner exists in this repo; `npm run check` passes with no new type errors across all new composables/components/schema.)
- [x] 7.6 Run targeted Rails tests and frontend checks affected by the implementation. (All backend bulk-user-import tests pass; `npm run check` clean.)
