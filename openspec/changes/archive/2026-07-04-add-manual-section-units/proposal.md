## Why

The current setup flow lets users define sections manually, but unit creation is separated from the section-level structure view. Users need a manual way to add, edit, and remove units directly from each eligible section while preserving the same tree interaction model used in the manual builder.

## What Changes

- Add a new manual unit mode in the unit step using the same visual pattern as `ManualSectionForm` and `ManualSectionTreeRow`.
- Replace section actions in this unit-management view with only an "add unit" action for eligible section rows.
- Reuse the manual section creation pattern for individual and multiple unit creation, including all-or-nothing multiple creation.
- Add per-unit dropdown actions for edit and delete.
- Add a unit edit dialog for `area_m2`, optional `display_name`, `unit_type`, and `identifier`.
- Regenerate server-derived unit `code` when `identifier` changes.
- Require confirmation before deleting a unit and perform deletion as a soft delete.
- Keep tenant isolation, section eligibility, unit uniqueness, lifecycle, and authorization enforced through existing domain services and policies.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `property-setup-wizard`: Step 3 gains a manual unit creation and management mode while reusing the manual section tree interaction model.
- `manual-structure-builder`: The shared preview receives a unit-management mode where section rows expose only unit creation and unit rows expose edit/delete actions.
- `unit`: Unit lifecycle requirements clarify manual wizard create/edit/delete behavior, all-or-nothing multiple creation, code regeneration on identifier edit, and soft delete through an explicit lifecycle operation.

## Impact

### Bounded context

- Affected domains: Residential Properties, Property Sections, Units, Property Setup Wizard.
- Integration points: Rails wizard controllers/services, Unit domain services, PropertySection eligibility rules, Inertia props, Vue step 3 pages/components, shared structure preview, Zod/VeeValidate unit forms, i18n keys.

### Affected models, services, and tables

- Models: `ResidentialProperty`, `PropertySection`, `Unit`.
- Services: `Properties::Setup::*`, `Units::Create`, `Units::Update`, a supported unit soft-delete lifecycle service if present or added for this change.
- Tables: `residential_properties`, `property_sections`, `units`.

### Tenant isolation and authorization

- All unit reads and writes remain scoped to the draft property and current organization.
- Manual unit creation, edit, and deletion require the `manage_units` permission for the draft property.
- Section IDs submitted from the client must be resolved through the current draft property; foreign or ineligible sections are rejected without exposing cross-tenant data.

### Dependencies

- Depends on the existing property setup wizard, manual structure builder, property-section, and unit contracts.
- No dependency on another in-progress OpenSpec change is assumed.

### Non-goals

- No bulk Excel import redesign.
- No changes to ownership, occupancy, visit, or resident flows.
- No hard-delete behavior for units.
- No placement move from the edit dialog; changing a unit's section remains a separate supported lifecycle operation.
- No exact visual replication beyond the observable behavior and existing design system conventions.
