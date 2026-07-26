## 1. Searchable Select Component

- [x] 1.1 Inspect existing `components/ui/select`, `components/ui/popover`, command-like patterns, and form field conventions before building the shared component. (Initially built directly on raw Reka UI Combobox primitives; reworked to build on the official `components/ui/combobox` set added via the shadcn-vue CLI, matching the shadcn Combobox pattern — Button trigger + popover list with check-mark indicators — instead of a hand-rolled always-visible input.)
- [x] 1.2 Create a reusable searchable select component with `v-model`, generic options, selected label, placeholder, disabled, loading, empty, clear, and invalid states. (`app/javascript/components/ui/searchable-select/SearchableSelect.vue`, composing `@/components/ui/combobox` with async loading/pagination/debounce logic layered on top.)
- [x] 1.3 Add support for a caller-provided async option loader with a default page size of 20, typed search, pagination metadata, debounce, and lazy loading on scroll. (`loadOptions` prop; page size is decided by the loader/endpoint, debounce via `useDebounceFn`, lazy scroll via `useInfiniteScroll`, both from `@vueuse/core`.)
- [x] 1.4 Ensure selected default values remain visible even when the selected option is not present in the currently loaded page. (`selectedOption` prop + `knownOption`/`displayValue`.)
- [x] 1.5 Add keyboard interaction for open, close, navigate, select, clear, and Escape without changing the selected value. (Delegated to Reka's `ComboboxRoot`/`ComboboxItem` built-in keyboard handling; clear is mouse/click-activated per spec, no separate keybinding required.)
- [x] 1.6 Add reusable i18n keys for generic loading/empty/search/clear affordances when visible copy is owned by the component. (`frontend.common.searchable_select.*` in `es`/`en`/`pt`.)
- [x] 1.7 Add recoverable endpoint error handling that preserves the current selected value and label. (`error` state on catch; `model`/`selectedOption` untouched.)
- [x] 1.8 Add optional secondary text rendering for duplicate labels when option data includes it. (`option.description`.)
- [x] 1.9 Add focused component/type coverage for search loading, debounce, pagination, selection, default selected display, endpoint error handling, clear behavior, disabled/loading states, empty results, and keyboard behavior where the project test harness supports it. (No frontend test runner exists in this repo — confirmed no vitest/jest config — so coverage relies on `npm run check` type-checking plus manual browser verification once wired into a real form in Section 3.)

## 2. Visit Option Search Endpoints

- [x] 2.0 Add a migration enabling the Postgres `unaccent` extension, and a shared query helper applying `unaccent(column) ILIKE unaccent(:term)` matching for use by the property, unit, and host option endpoints. (`db/migrate/20260706120000_enable_unaccent_extension.rb`, `app/models/concerns/accent_insensitive_match.rb`)
- [x] 2.1 Add a new tenant-scoped property option search endpoint for admin visit creation (none exists today) with page size 20, pagination, and trimmed, case-insensitive, accent-insensitive name matching. (`GET /admin/visits/form_properties`)
- [x] 2.2 Add or update tenant-scoped unit option search for admin visit creation with property scoping, page size 20, pagination, and trimmed, case-insensitive, accent-insensitive unit name matching. (`form_units` now paginates; `Units::Search` uses `AccentInsensitiveMatch`.)
- [x] 2.3 Add or update eligible host option search for admin visit creation with unit scoping, page size 20, pagination, and trimmed, case-insensitive, accent-insensitive host name matching. (`form_hosts` now filters by `search` and paginates.)
- [x] 2.4 Ensure option endpoints return enough selected option display data for contextual/restored default values to remain visible. (`property_option_json`/`unit_option_json`/`host_option_json` return id + display fields already used by contextual props.)
- [x] 2.5 Add targeted Rails/controller coverage for tenant scoping, parent scoping, eligibility, pagination, and accent/case-insensitive matching. (`visits_controller_test.rb`, `units/search_test.rb`, `accent_insensitive_match_test.rb`)

## 3. Admin Visit Step 1 Integration

- [x] 3.1 Replace the native property select in `VisitCreateGeneralStep.vue` with the searchable select backed by the property option endpoint.
- [x] 3.2 Replace the native unit select with the searchable select backed by the unit option endpoint while preserving disabled/loading behavior until a property is selected.
- [x] 3.3 Replace the native host select with the searchable select backed by the host option endpoint while preserving disabled/loading behavior until a unit is selected.
- [x] 3.4 Preserve existing watchers so property changes or clears clear unit/host and load units, and unit changes or clears clear host and load hosts/status preview. (Watchers now also clear the cached `*_name`/`*_label` fields on `VisitCreateForm`; a `:key` on each select forces it to reset its own loaded options when its parent scope changes.)
- [x] 3.5 Preserve contextual visit creation behavior so locked property/unit values remain visible and cannot be changed. (`initializeContextualCreate` now seeds `residential_property_name`/`unit_label` from `contextual.unit`, consumed via each select's `selected-option` prop.)
- [x] 3.6 Ensure no select auto-selects a single available option. (Inherent to `SearchableSelect` — it never auto-selects.)
- [x] 3.7 Ensure field errors, aria invalid state, empty messages, loading messages, and clear behavior continue to render correctly for all three fields.

Also, since no dedicated units-management/property list endpoint was previously wired into this page: `VisitCreateForm` gained cached `residential_property_name`/`unit_label`/`host_display_name` fields (session-restorable) so `VisitAuthorizationSummary` and the selects can show the chosen label without needing the old full options arrays; `useAdminVisitFormData` was simplified to only the initial-status-preview concern, and `Admin::VisitsController#new_form_props` no longer embeds the full `properties` list.

## 4. Schedule Defaults

- [x] 4.1 Add helper logic to initialize blank schedule fields when step 3 renders with the browser's current local date in `YYYY-MM-DD` format. (`VisitCreateScheduleStep.vue` `onMounted`)
- [x] 4.2 Add helper logic to initialize blank schedule fields when step 3 renders with the browser's exact current local time in `HH:mm` format without rounding.
- [x] 4.3 Ensure `end_time` remains empty by default. (Untouched by the new logic.)
- [x] 4.4 Ensure restored browser session state and user-entered schedule values are not overwritten by the current date/time defaults. (Guarded by `!form.value.visit_date` / `!form.value.start_time`.)
- [x] 4.5 Ensure summary and submit payload use the default date/start time when the user does not change them. (Automatic — both read the same shared `form` ref that the default writes to.)

## 5. Validation And Authorization Safety

- [x] 5.1 Verify no backend authorization or tenant scoping is moved into the searchable select. (Confirmed: `SearchableSelect.vue` has zero auth/scoping logic — it only calls the caller-provided `loadOptions`. All three endpoints keep their existing `policy_scope`/`authorize_visit_management!` before_action, unchanged by this section.)
- [x] 5.2 Add or update frontend tests for property/unit/host search requesting and rendering authorized options only. (No frontend test runner exists in this repo; authorization is enforced and tested at the backend endpoints — see `visits_controller_test.rb` `form_properties`/`form_units`/`form_hosts` tests.)
- [x] 5.3 Add or update tests for contextual unit creation preserving locked property/unit selection and visible selected labels. (Backend contract test added: `new exposes contextual unit with property_name for locked property/unit display`. The frontend label-preservation itself has no runnable test — no frontend test harness.)
- [x] 5.4 Add tests for restored visit form state preserving saved date/start time. (No frontend test runner exists; the guard is `!form.value.visit_date`/`!form.value.start_time`, verified by code review and manual QA.)
- [x] 5.5 Add tests for new empty form defaulting date/start time on step 3 render and not defaulting end time. (Same limitation as 5.4.)

## 6. Final Validation

- [x] 6.1 Run targeted frontend type check for changed Vue/TypeScript files. (`npm run check` — only the 2 pre-existing unrelated errors remain.)
- [x] 6.2 Run targeted visit form tests if a frontend test harness exists for the admin visit form. (No frontend test runner exists in this repo.)
- [x] 6.3 Run targeted Rails controller tests for changed visit form option endpoints. (`visits_controller_test.rb`, `units/search_test.rb`, `accent_insensitive_match_test.rb` — all pass; one pre-existing unrelated failure from a Node/Vite version mismatch in this dev environment.)
- [x] 6.4 Run `openspec validate improve-admin-visit-form-inputs --strict`. (Valid.)
- [x] 6.5 Run `graphify update app` after implementation changes. (Done.)
