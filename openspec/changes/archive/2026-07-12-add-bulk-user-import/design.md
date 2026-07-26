## Context

The current bulk units flow uses `BulkImport` and `BulkImportRow` as generic import records, with unit-specific services for upload metadata, column mapping, validation, preview, confirmation, processing, status polling, and reporting. The Vue drawer follows four steps: method, configure, preview, and import. It uses Zod/VeeValidate in the configure step and row-level preview before confirmation.

User/person import should follow that same UX and lifecycle while targeting the unified identity model. `Person` is the organization-scoped identity record; `User` represents login access and is out of scope for this import. The UI entry point lives in the `/admin/people` view as a drawer.

Affected models and tables: `bulk_imports`, `bulk_import_rows`, `people`, `organization_memberships`, and `users` only for email conflict checks against linked people.

Affected integration points: Active Storage file upload, spreadsheet inspection/reader, bulk import serializers/reports/status payloads, Pundit policies, Sidekiq/background import processing, Vue drawer components, frontend schemas, shared routes, and i18n keys under admin bulk import/user import namespaces.

## Goals / Non-Goals

**Goals:**
- Add a bulk user/person import drawer to `/admin/people` using the existing bulk import lifecycle and drawer semantics.
- Validate required fields: first name, last name, document, phone, email, and birthdate.
- Require phone presence without enforcing a phone format in this version.
- Enforce birthdate parsing strictly as `DD/MM/YYYY`.
- Scope validation, duplicate detection, preview rows, and created people to the current organization.
- Create active natural `Person` records and organization memberships for imported rows.
- Preserve partial import behavior: row failures do not abort the whole batch.

**Non-Goals:**
- Create login `User` accounts, passwords, or invitations.
- Assign system roles, property roles, ownerships, occupancies, staff assignments, or visitor profiles.
- Update existing people in the first version.
- Replace the existing bulk units implementation.
- Add a new identity table.

## Decisions

### Decision: Reuse `BulkImport` and `BulkImportRow` with `import_type=users`

Use the existing state machine and row storage for the new import type. Add user-specific service objects under `BulkImportServices`, mirroring the unit services where behavior is domain-specific.

Rationale: the units flow already solves upload, validation, row preview, progress, and reporting. Reusing the lifecycle keeps admin behavior consistent and avoids a second import framework.

Alternative considered: create a separate `UserImport` model. Rejected because it would duplicate state handling and conflict with the generic `BulkImport` table already designed for multiple import types.

### Decision: Create `Person`, not `User`

Imported rows create active natural `Person` records in the `people` table with `first_name`, `last_name`, `birthdate`, `document_number`, `contact_phone`, and `contact_email`. No login account is created.

Rationale: the unified person profile spec defines `Person` as the single identity record per organization, while `User` is login access. The requested fields match person identity/contact data rather than authentication credentials.

Alternative considered: create both `Person` and `User`. Rejected for this change because it implies invitation, password, role, and access semantics that were not requested.

### Decision: Create the organization membership using the existing `create! + accept!` pattern

Each imported row's `Person` gets an `OrganizationMembership` created via `OrganizationMembership.create!(organization:, person:)` followed by `membership.accept! if membership.may_accept?` — the same two-step pattern already used in `app/services/unit_ownerships/create_with_person.rb`, `unit_occupancies/create_with_person.rb`, `visits/resolve_visitor_person.rb`, `User#...` and, notably, `Admin::PeopleController#ensure_membership!` (the exact controller this import extends).

Rationale: `BulkImportServices::ResolveImportOwnerPerson` — the person-resolution service this change otherwise mirrors — creates a `Person` and assigns a role, but never touches `OrganizationMembership` at all. Following it here would silently skip membership creation. The `create! + accept!` pattern is the actual established convention for "person should already be an active member" elsewhere in the codebase, so the row importer should call it directly rather than treating `ResolveImportOwnerPerson` as a template for this part.

Alternative considered: leave membership status as the default `invited`. Rejected because these are bulk-imported people the admin already knows to be part of the organization, matching how every other "add a person now" flow in this codebase immediately accepts the membership rather than leaving it pending.

### Decision: Implement user-specific mapper, validator, context, and processor

Introduce user/person counterparts to the unit services, such as column mapper, spreadsheet reader, validation context, row validator, create/update import, confirm import, process import, and row importer. Keep shared services for list rows, reports, status payloads, metadata, and file inspection when they remain import-type agnostic.

Rationale: the bulk lifecycle is shared, but required fields, duplicate rules, date parsing, normalized payload, and record creation are person-specific.

Alternative considered: heavily parameterize the units services. Rejected because owner/unit logic is specialized and would make both imports harder to reason about.

### Decision: Strict row-level validation before execution

Validation stores row errors and warnings before confirmation. Required field, email format, exact `DD/MM/YYYY`, impossible dates, future birthdates, file duplicates, and organization duplicates are detected before processing.

Rationale: the existing drawer expects admins to review errors before import. Strict dates avoid silent spreadsheet coercion or locale ambiguity.

Alternative considered: rely on model validation during import. Rejected because it would defer predictable row issues until after confirmation and reduce preview usefulness.

### Decision: Duplicate behavior starts with create/skip semantics

Default mode should skip duplicate identities. A create-only mode may treat duplicates as errors, matching the unit import mode pattern. No update mode is required for the first version.

Rationale: duplicate handling is the main operational ambiguity. Skipping duplicates is safer for initial bulk creation and mirrors the current default units behavior.

Alternative considered: update existing people by document/email. Rejected for the first version because field overwrite rules, audit messaging, and conflict resolution need separate product decisions.

### Decision: Frontend mirrors bulk units while allowing reuse where clean

Build a bulk user/person drawer in `/admin/people` with the same steps and button behavior as `BulkUnitsImportDrawer`. Extract shared composables/components only when duplication is clearly mechanical and does not obscure unit-specific wording.

Rationale: keeping the first implementation close to the proven units flow reduces risk. Small shared pieces can be extracted once both flows reveal stable common contracts.

Alternative considered: fully generic bulk import UI immediately. Rejected because field tables, summaries, copy, and domain-specific rules differ enough that premature generic UI could slow implementation.

## Risks / Trade-offs

- Duplicate detection by both document and email can find conflicting existing people -> Mark the row as an error and expose the conflicting field in preview/report rather than choosing an arbitrary record.
- Email uniqueness has no database-level backing, unlike `document_number` (`document_number_digest` has a real unique index; email dedup only checks `metadata->>'import_email'` via a plain Ruby validation, with no expression index). This means (a) checking email duplicates against a large existing organization can be slow, since the generic GIN index on `metadata` does not accelerate `->>'key' = value` lookups, and (b) two concurrent bulk imports (or a bulk import racing the manual "add person" form) have no DB constraint stopping two `Person` records from getting the same email — only document has that backstop. **Accepted for this version**: this mirrors an existing, long-standing limitation of the manual person-creation flow, not a regression introduced by this change. Row-level import processing is sequential within a single `BulkImport` (one Sidekiq job per import), so the practical risk is limited to genuinely concurrent imports, not rows within the same file. Revisit with a real `email_digest` + unique index if this becomes an observed problem.
- Spreadsheet date cells may arrive as serial numbers or locale-specific strings -> Normalize reader output but require final accepted string/date to satisfy exact `DD/MM/YYYY` semantics before storing.
- Large imports may be slow in the drawer -> Reuse background processing and polling; refresh counters in batches as units import does.
- User-facing text spans Rails and Vue -> Add i18n keys in `es`, `en`, and `pt` for validation messages, drawer labels, actions, logs, and report statuses.
- Reusing the current residential-property-scoped bulk import routes does not fit organization-level people import -> Use organization/admin people routes for this drawer and keep all lookup scoped by organization.
- Existing report/status services may contain unit-specific messages -> Branch by `import_type` or inject message builders so user import logs and reports name people/users accurately.

## Migration Plan

1. Add code paths for `BulkImport::IMPORT_TYPES[:users]` without changing existing rows.
2. Add user import services, frontend drawer, routes/controllers, serializers/types, policy checks, and i18n.
3. Add focused tests for mapper, validator, duplicate detection, strict date parsing, processing, authorization, and frontend schemas/composables.
4. Deploy with no data migration required unless a missing import type enum/index constraint is discovered during implementation.
5. Rollback by hiding/removing the user import entry point; existing `BulkImport` rows remain inert historical records.

## Open Questions

- None for this change. Resolved: `BulkImportRow` already models `duplicate` as its own `validation_status`, distinct from `warning`, and `valid_for_import?` only allows `valid`/`warning` — `duplicate` is never importable, in either duplicate-handling mode. The existing units validator (`BulkImportServices::UnitsImportRowValidator`) implements this exactly: a duplicate adds a `warning`-coded validation issue in skip mode (or an `error` in create-only mode), then reclassifies the row's final `validation_status` to `duplicate` whenever any warning code starts with `"duplicate"`, and sets `import_status: skipped` right at validation time when in skip mode — not deferred to confirmation/execution. The bulk user import MUST mirror this exact mechanism rather than treating `duplicate` as a subtype of `warning`.
