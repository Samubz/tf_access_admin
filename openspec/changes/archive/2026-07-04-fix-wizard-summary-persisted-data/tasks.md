## 1. Backend Summary Contract

- [x] 1.1 Inspect the current property setup wizard controller, serializer/prop builder, and step 4/5 data flow to identify where summary and confirmation props are built.
- [x] 1.2 Replace stale, estimated, or client-derived summary counts with persisted database-backed counts scoped to the current organization and draft property.
- [x] 1.3 Ensure property detail fields in "Datos de la propiedad" are read from the saved `ResidentialProperty` record.
- [x] 1.4 Ensure section totals and nested section data exclude deleted sections and records outside the current property.
- [x] 1.5 Ensure unit totals and nested unit data count non-deleted persisted section-associated `Unit` records across manual, automatic, and import-created units, excluding units whose section is soft-deleted.
- [x] 1.6 Remove `estimated_units` from `Properties::Setup::ValidateStep#validate_step_1` (blank and greater-than-0 checks) so step 1 no longer requires or blocks on it.
- [x] 1.7 Remove the `estimated_units` key from backend setup params, prop builders (including `BuildPreview#property_summary`), and serializers. Do not repoint the same key to a persisted count under its old name; use the already-available `counts.units` (or an equivalently named authoritative field) instead.
- [x] 1.8 Reuse one backend summary contract or prop builder for step 4 summary, step 5 confirmation, and the post-confirmation completed view.

## 2. Frontend Consumption

- [x] 2.1 Inspect the Vue components for setup summary and confirmation to find any local recomputation from partial preview or form state.
- [x] 2.2 Update step 4 summary components to display backend-provided persisted property, section, and unit totals.
- [x] 2.3 Update step 5 confirmation and post-confirmation completed components (`Step5Confirm.vue`, `Step5Completed.vue`) and the shared `UnitsPreviewPanel.vue` to display the same persisted summary contract as step 4, replacing all reads of `preview.property.estimated_units`.
- [x] 2.4 Remove the estimated unit count input and any related display from the step 1 property data UI.
- [x] 2.5 Remove obsolete estimated-unit validation/schema/i18n keys where they are no longer used.
- [x] 2.6 Preserve existing i18n usage and add `es`, `en`, and `pt` keys only if new user-facing text is required.
- [x] 2.7 Ensure navigation after step 3 mutations reloads or receives fresh persisted summary props before review/confirmation.

## 3. Regression Coverage

- [x] 3.1 Add focused Rails tests proving a draft property with 24 non-deleted persisted units shows 24 in step 4 summary props.
- [x] 3.2 Add focused Rails tests proving step 5 confirmation props show the same unit total as step 4.
- [x] 3.3 Add tests proving units from another property or organization are excluded from summary and confirmation counts.
- [x] 3.4 Add tests proving soft-deleted units are excluded from ordinary visible totals and nested previews.
- [x] 3.5 Add tests proving soft-deleting one of 24 persisted units reduces summary and confirmation totals to 23.
- [x] 3.6 Add tests proving units under soft-deleted sections are excluded from ordinary visible totals and nested previews.
- [x] 3.7 Add tests proving step 5 confirmation reloads current persisted totals instead of reusing stale step 4 state.
- [x] 3.8 Add tests or type checks proving the estimated unit count input is removed and no summary value depends on it.
- [x] 3.9 Add focused frontend type or component-level validation if prop shapes or TypeScript types change.
- [x] 3.10 Add a test proving `ValidateStep#validate_step_1` succeeds without an `estimated_units` param.
- [x] 3.11 Add a test proving the post-confirmation completed view shows the same persisted unit total as step 4/5, not an estimated unit count.

## 4. Validation

- [x] 4.1 Run the targeted Rails tests covering property setup wizard summary and confirmation behavior.
- [x] 4.2 Run the focused frontend type check if Vue/TypeScript props changed. `npm run check` shows only 2 pre-existing, unrelated errors (`MultiFileGridUpload.vue`, `useUnitAddOwnerDrawer.ts`); no new errors from this change.
- [x] 4.3 Run `openspec validate fix-wizard-summary-persisted-data --strict`.
- [x] 4.4 Run `graphify update app` after implementation changes.
