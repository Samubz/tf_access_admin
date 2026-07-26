## Context

The admin visit creation page (`/admin/visits/new`) is a multi-step Inertia/Vue form. Step 1 currently uses native selects for property, unit, and host. Units and hosts are loaded through existing tenant-scoped endpoints after a property or unit is selected. Step 3 currently renders date and time inputs but starts with empty `visit_date` and `start_time` values from `createEmptyVisitCreateForm`.

The form becomes harder to use as the number of properties, units, and eligible hosts grows. The most common visit schedule also starts "now", so requiring users to manually enter the current date and start time slows down creation.

Affected models, services, database tables, and integration points:

- Models/tables: `Visit`, `ResidentialProperty`, `Unit`, `Person`, `StaffAssignment`, `UnitOwnership`, `UnitOccupancy`.
- Controllers/services: `Admin::VisitsController#new`, `#form_units`, `#form_hosts`, `#initial_status_preview`, `Visits::EligibleHosts`.
- Frontend: `VisitCreateGeneralStep.vue`, `VisitCreateScheduleStep.vue`, `useAdminVisitCreate`, `useAdminVisitFormData`, `visit_create.ts`, shared `components/ui`.
- Authorization: existing visit, unit, host, property policy scopes remain the authority for option visibility.

## Goals / Non-Goals

**Goals:**

- Add a reusable searchable select component for endpoint-backed option lists.
- Use the searchable select for property, unit, and host selection in admin visit creation step 1.
- Provide at least 20 initial options per select and lazy-load additional pages when the user scrolls without filtering.
- Search remotely by property name, unit name, and host name.
- Preserve dependent selection behavior: property -> units -> hosts/status preview.
- Preserve contextual creation locks when the form is opened from a unit.
- Default new visit forms to the browser's exact current local date and current local start time when step 3 renders.
- Preserve restored in-progress form values instead of overwriting them with new defaults.
- Keep validation and server-side authorization unchanged.

**Non-Goals:**

- Do not change `form_units`, `form_hosts`, or host eligibility semantics unless needed to preserve existing behavior.
- Do not change visit persistence, authorization, initial status resolution, or resident/private visit flows.
- Do not default `end_time`.
- Do not migrate every select in the application to the new component.

## Decisions

1. Build a reusable endpoint-backed searchable select component.

   The component should live under shared UI/component code and accept generic option data (`value`, `label`, optional description/metadata), an async option loader, pagination state, and an optional selected option label/value pair. It searches by asking the caller-provided loader for options, not by knowing visit-specific APIs. Alternative considered: adding bespoke filtering inside `VisitCreateGeneralStep`. That would solve this page only and make future reuse harder.

   Built as `SearchableSelect.vue`, composing the official `components/ui/combobox` primitives (added via the shadcn-vue CLI, matching [ui.shadcn.com's Combobox pattern](https://ui.shadcn.com/docs/components/radix/combobox): a `Button` trigger showing the selected label + chevron, opening a popover with a search input and check-mark item indicators) with the async loader/pagination/debounce/error-recovery logic layered on top in the composing component.

2. Keep option authorization server-side.

   The searchable select only renders options returned by authorized endpoints. It must not query global records or infer hidden options. Search endpoints must keep existing policy scopes, tenant scoping, parent filters, and host eligibility rules.

3. Support initial options and lazy scroll pagination.

   Each select should request 20 options per page by default and have at least 20 options available before the user types when that many authorized options exist. If the user opens the select and scrolls without filtering, the component should request the next page lazily. Typed searches should reset pagination and return matching results. If the select has an existing/default value, the selected label must remain visible even if that option is not part of the currently loaded page.

4. Preserve select-like form semantics.

   The component should support `v-model`, disabled/loading states, placeholder text, empty state text, validation aria state, keyboard navigation, clear/select behavior, and visible selected value. It should behave as a form control replacement for `NativeSelect`, not as a one-off autocomplete. Clearing property must clear unit and host. Clearing unit must clear host and dependent status preview.

5. Default date/time when step 3 renders.

   The current date and start time should be set when the schedule step is first rendered for a new empty visit form and the fields are still blank. Restored session state and user-entered values remain authoritative so users do not lose in-progress values after navigation or failed submission. The start time uses the exact current browser time in `HH:mm` format and is not rounded to fixed intervals.

6. Use browser local time for frontend defaults.

   Inputs are `date` and `time` controls and the existing submit path combines them with `new Date(date + "T" + time)`. Defaults should use the browser's local date and time in the same shape (`YYYY-MM-DD`, `HH:mm`) to avoid UTC date drift in the UI.

7. Search matching semantics.

   Property search matches property name, unit search matches unit name, and host search matches host name. Matching should trim surrounding whitespace, be case-insensitive, and be accent-insensitive so searches without accents can match names with accents (e.g. "region" matches "Región").

   No accent-insensitive strategy exists anywhere in the project today: the only established pattern (`Units::Search#apply_term`) uses plain `ILIKE`, which is case-insensitive but not accent-insensitive, and no `unaccent`/`pg_trgm` extension is enabled (`db/schema.rb` only enables `btree_gist`, `plpgsql`, `pgcrypto`). Filtering in Ruby after fetching would defeat the server-side pagination required by Decision 3 for potentially large option sets.

   Decision: enable the Postgres `unaccent` extension via migration and match with `unaccent(column) ILIKE unaccent(:term)` (wrapped in a shared query helper so all three endpoints — property, unit, host — apply it consistently). This is a one-line, reversible `enable_extension` migration with no data changes. Alternative considered: Ruby-side transliteration. Rejected because it cannot be combined with efficient DB-side pagination without also introducing a persisted normalized column, which is more invasive than enabling a stock Postgres extension.

8. Do not auto-select single-option results.

   A select with exactly one visible option must still wait for explicit user selection. This applies to property, unit, host, initial loads, filtered results, and contextual host loading.

9. Internationalize generic and visit-specific copy.

   Any visible generic searchable select text should have reusable i18n keys, and visit-specific placeholders/loading/empty copy should keep using the visit namespace where applicable.

10. Debounce remote searches and preserve selected values on errors.

   Typed search requests should use a short debounce so the UI does not call the endpoint on every keystroke. If an option endpoint fails, the select should show an error or recoverable empty state and keep the current selected value visible instead of clearing it.

11. Handle duplicate display names with secondary text.

   Search still matches only the required name field, but if multiple returned options share the same visible name, the select may show secondary descriptive text from already-available option data to help users choose the correct record.

## Risks / Trade-offs

- [Risk] Search endpoints can accidentally widen tenant or eligibility scope. -> Mitigate with policy scopes, parent filters, and targeted controller tests.
- [Risk] Scroll pagination and typed search can race. -> Mitigate by ignoring stale responses and resetting pagination when the query or parent filter changes.
- [Risk] Selected values may disappear when not in the first page. -> Mitigate by passing or loading the selected option label separately from the current option page.
- [Risk] Endpoint failures can make the selected value look lost. -> Mitigate by preserving the selected label/value while showing a recoverable error or empty state.
- [Risk] Time defaults may become stale before step 3. -> Mitigate by applying defaults when step 3 first renders, not when the page first opens.
- [Risk] Restored forms could be overwritten. -> Mitigate by applying defaults only when creating an empty form, and preserving session restore snapshots.
- [Risk] Searchable select accessibility can regress compared to native select. -> Mitigate with keyboard support, focus management, ARIA labels/states, and tests/manual QA.
- [Risk] Accent-insensitive backend search can differ by database collation. -> Mitigate by using the Postgres `unaccent` extension explicitly (Decision 7) instead of relying on collation, and cover it with targeted tests across property/unit/host endpoints.

## Migration Plan

- Add a migration enabling the Postgres `unaccent` extension (no data/table changes).
- Add the shared endpoint-backed searchable select component.
- Add or update visit form option search endpoints, including a new property option endpoint (none exists today — properties are currently embedded as a static, unpaginated prop).
- Replace the three step 1 native selects in admin visit creation.
- Add date/time default helpers when the schedule step renders.
- Rollback disables the `unaccent` extension (safe: no data or columns depend on it), returns step 1 to native selects, and restores empty date/start-time defaults.

## Open Questions

- None.
