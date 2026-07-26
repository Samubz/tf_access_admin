## Why

The setup wizard currently behaves like a one-way flow: once structure and units exist, returning to earlier steps can leave stale sections/units unless the destructive impact is explicit. The business needs an editable post-wizard state where property data and structure can still be adjusted safely before the property is confirmed.

## What Changes

- Add a new `created` property lifecycle state for completed-but-editable wizard output.
- Let the final wizard step finish as either `created` (editable) or `configured`.
- Allow `created`, `configured`, and `active` properties to reopen the wizard from step 1 and edit property identity fields, property type, building format, sections, and units.
- Define property identity fields as `address_line`, `city`, `country`, `name`, `property_type`, `region`, and `timezone`.
- Derive `normalized_name` from `name`, and derive property `code` from the property type abbreviation plus `normalized_name`, reusing the existing implemented code-generation convention.
- Reject name/type edits that would generate a colliding property `code`, and tell the client to change the property name.
- Preserve lifecycle direction: `configured` can only transition to `active`; `active` can only transition to `archived` and cannot move back to `configured`.
- Treat building format as the full `PropertyStructureFormat` catalog introduced by `2026-06-29-improve-property-structure-wizard-formats`.
- When draft/created/configured/active wizard editing changes property type, building format, or structure mode after sections/units exist, require a confirmation dialog before resetting the existing structure.
- After confirming the destructive reset, `draft` properties really destroy existing sections and units; `created`, `configured`, and `active` properties soft-delete existing sections and their associated units.
- Restrict created/configured/active property editing in the wizard to manual section and manual unit management; quick automatic structure/unit generation is only for draft first-time setup before a persisted structure is committed.
- Treat manual section soft-delete as independent from destructive reset; deleting one section soft-deletes that section and its units only, unless the section or a unit has operational history, in which case both are archived behind an explicit confirmation instead.
- Add a "manage unit" action to step 3 unit rows that opens the existing, non-wizard unit detail page.
- Add "move section to a different parent" as a native wizard capability, reusing the existing move service.
- Retire the standalone, non-wizard property structure page and its dedicated mutation controller; redirect the one other entry point that linked to it (the organization-wide flat section directory's edit action) into the wizard instead.
- Retire the standalone, non-wizard property edit page (`Admin::ResidentialPropertiesController#edit/update`, `Properties::Update`) now that the wizard covers the same identity fields for `draft`/`created`/`configured`/`active`; redirect entry points that linked to it (property catalog row action, person profile occupancy/ownership property links) into the wizard instead.
- Preserve tenant isolation and property-scoped authorization for all edit, reset, section, and unit operations.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `residential-property`: Property lifecycle adds `created` and clarifies which statuses allow property field edits, structure edits, and operational mutations.
- `property-setup-wizard`: Wizard can edit existing draft/created/configured/active properties, introduces final `created` vs `configured` outcomes, destructive reset confirmation, and manual-only editing modes for created/configured/active properties.
- `manual-structure-builder`: Manual section management applies to draft and created/configured/active wizard edit contexts, with destructive resets handled by the wizard.
- `unit`: Manual wizard unit creation/edit/delete applies to created/configured/active wizard edit contexts as well as draft setup where allowed.

## Bounded Context

Affected domains and integration points:

- Residential property lifecycle and status transitions.
- Property setup wizard steps 1 through 5.
- Manual property section builder and unit-management mode.
- Property setup serializers, controllers, policies, service objects, and Vue/Inertia pages.

Affected models, services, and tables:

- Models: `ResidentialProperty`, `PropertySection`, `Unit`.
- Services/controllers: property setup initialize/update/confirm/configure flows, section reset cleanup, manual section/unit mutations.
- Tables: `residential_properties`, `property_sections`, `units`.

Dependencies on other OpenSpec changes:

- Depends on the archived manual section/unit wizard work and persisted summary work now present in main specs.

## Impact

- Tenant isolation remains mandatory: structure resets and edit flows must be scoped to the current organization and current property.
- Authorization remains property-scoped: only users with setup/manage-property/manage-units capabilities may edit the relevant pieces.
- The change likely requires a model enum/status update, lifecycle transition updates, controller/service changes, frontend confirmation dialog work, and regression tests.
- Destructive structure resets must be explicit, confirmed by the user, and all-or-nothing.

## Non-goals

- Do not block `configured` or `active` properties from wizard editing in this change; they are editable like `created` for now.
- Do not enable quick automatic structure or unit generation for already `created`, `configured`, or `active` properties.
- Do not change ordinary post-confirmation administration flows outside the setup wizard, beyond retiring the now-redundant structure and property-edit pages explicitly listed above.
- Do not hard-delete historical records outside explicit `draft` structure reset behavior.
- Do not extend wizard editability to `inactive` properties in this change. Retiring the standalone property-edit page therefore leaves `inactive` properties with no field-editing path until a follow-up decision — accepted as a known gap rather than solved here.
