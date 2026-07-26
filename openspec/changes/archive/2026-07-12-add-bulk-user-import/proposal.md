## Why

Administrators need a fast, auditable way to load many people into an organization without creating them one by one. The existing bulk units drawer already establishes a familiar upload, configure, preview, and confirm flow; user/person import should reuse that model so admins can correct row-level issues before any records are created.

## What Changes

- Add a bulk person import flow from `/admin/people` for spreadsheet/CSV files with required columns: first name, last name, document, phone, email, and birthdate in `DD/MM/YYYY` format.
- Reuse the current bulk import wizard semantics: upload method, sheet/configuration step, column mapping validation, preview with row statuses, option to import only valid rows, confirmation, progress polling, logs, and downloadable report.
- Validate each row before import and show row-level errors for missing required fields, invalid email, invalid or impossible birthdate, duplicate document/email in the file, and duplicate document/email in the organization.
- Create tenant-scoped `Person` records in the `people` table, not `User` login accounts or a parallel identity table, using the existing unified person identity rules for document/email uniqueness.
- Keep failed rows isolated so one bad row does not stop valid rows from importing.

## Capabilities

### New Capabilities
- `bulk-user-import`: Bulk import workflow, validation rules, preview, execution, and reporting for organization people managed from `/admin/people`.

### Modified Capabilities
- `unified-person-profile`: Bulk user import MUST create and deduplicate `Person` records under the unified identity model.

## Bounded context

- Domains: Bulk Imports, Persons, Organizations, Authorization, Auditing, Admin frontend.
- Integration points: existing `BulkImport`/`BulkImportRow` state machine, Active Storage upload inspection, spreadsheet readers/mappers, Inertia/Vue admin screens, Pundit policies, Sidekiq processing, and unified person resolver/validations.

## Impact

- Affected models/tables: `BulkImport`, `BulkImportRow`, `Person`, `OrganizationMembership`, `User` only for email conflict detection when linked to a person.
- Affected services: new user/person-specific bulk import services mirroring the units import boundary; shared or extended metadata, row listing, report, and status services where reusable.
- Affected frontend: new drawer/composables/components exposed from `/admin/people` for person import or reusable bulk import components extracted from the units flow; frontend schemas and i18n keys.
- Affected APIs/routes: admin bulk import endpoints must support `import_type=users` or a scoped equivalent while preserving tenant isolation.
- Authorization: only users with the existing admin capability to manage people/users in the organization may upload, preview, confirm, poll, and download reports.
- Tenant isolation: all lookup, deduplication, validation, row listing, and import execution must be scoped to the current organization.
- Dependencies on other OpenSpec changes: none known.

## Non-goals

- Do not create `User` login accounts or send invitations as part of this import.
- Do not assign roles, unit ownerships, unit occupancies, or staff assignments during this import.
- Do not support updating existing people in the first version; duplicate existing identities are skipped or reported according to the import mode.
- Do not introduce a new identity table separate from `people`.
