## Why

The admin visit creation form currently uses native selects for property, unit, and host selection. Those controls become hard to use when the organization has many properties, units, or residents, and the schedule step requires repetitive manual entry for the most common case: creating a visit for now.

## What Changes

- Add a generic searchable select component that behaves like a select but lets users type to search options from an authorized endpoint.
- Replace the step 1 property, unit, and host native selects in `/admin/visits/new` with the searchable select component.
- Preserve current dependent-loading behavior: property selection loads units, unit selection loads eligible hosts and initial status preview, and contextual visit creation can still lock property/unit.
- Load at least 20 initial options per searchable select, support lazy loading more results on scroll, and keep selected default values visible even when they are not in the first loaded page.
- Preserve current empty, loading, disabled, validation, and keyboard-accessible states.
- Preload step 3 "Fecha y horario" with the browser's exact current local date and current local start time when the step renders for new visit forms.
- Preserve existing draft/session restore behavior so an in-progress form is not overwritten by the default date/time.

## Capabilities

### New Capabilities

- `searchable-select-control`: Defines a reusable UI control for select-like inputs with remote search, initial options, lazy scroll pagination, option display, disabled/loading/empty states, clear behavior, keyboard support, and form binding.

### Modified Capabilities

- `visit-management`: Admin visit creation uses searchable selects in the first step and defaults the schedule date/start time to the current local date/time for new forms.

## Bounded context

Affected domains and integration points:

- Admin visit creation flow at `/admin/visits/new`.
- Visit form step 1 location/host selection.
- Visit form step 3 schedule date/time defaults.
- Existing visit form data endpoints for units, hosts, and initial status preview.
- Shared frontend UI components for future reusable searchable select usage.

Affected models, services, and database tables:

- Models/tables: `Visit`, `ResidentialProperty`, `Unit`, `Person`, `StaffAssignment`, `UnitOwnership`, `UnitOccupancy`.
- Services/controllers: `Admin::VisitsController#new`, `#form_units`, `#form_hosts`, `#initial_status_preview`, `Visits::EligibleHosts`, visit creation form composables/schemas.
- Frontend: `app/javascript/pages/admin/visits/new.vue`, visit create step components, visit create schema/composable, new shared searchable select component.

Dependencies on other OpenSpec changes:

- No direct dependency on active changes. The change should coexist with the active `add-property-detail-view` proposal without modifying it.

Tenant isolation and authorization impact:

- Searchable selects MUST only display options returned by authorized, tenant-scoped props or endpoints.
- Remote search MUST NOT fetch or reveal cross-organization properties, units, hosts, or people.
- Existing server-side policy scopes and visit creation authorization remain authoritative.

## Impact

- Adds a reusable Vue UI component for searchable select behavior.
- Updates admin visit creation step 1 to use that component for property, unit, and host selection.
- Updates visit form initialization so new forms default `visit_date` and `start_time` to the user's current local date/time.
- Adds or updates tenant-scoped search endpoints for property, unit, and host options, including a brand-new property option endpoint (properties are currently embedded as a static, unpaginated page prop, not served by an endpoint).
- Adds a migration enabling the Postgres `unaccent` extension so property/unit/host name search can be accent-insensitive (no existing strategy in the project covers this; see design.md Decision 7).
- Adds frontend tests/type checks where available and targeted Rails/controller tests for changed search endpoints.
- Adds i18n keys for generic searchable select loading/empty/search affordances if the component displays user-facing text.

## Non-goals

- Do not change visit authorization, host eligibility, unit filtering, or visit creation persistence rules.
- Do not change the resident/private visit API flow.
- Do not add defaults for end time unless separately specified.
- Do not replace every select in the application; only create the reusable component and apply it to `/admin/visits/new` step 1.
