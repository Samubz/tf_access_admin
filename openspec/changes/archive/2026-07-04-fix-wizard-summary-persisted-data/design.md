## Context

The setup wizard already persists draft property data, sections, and units before the user reaches the summary and confirmation steps. Those final sections must act as a review of the saved database state, but the current UI can show values that appear derived from earlier form state or incomplete preview state. The reported example is a draft property with 24 persisted units where the summary/confirmation area shows only 1 unit.

Affected models and tables:

- `ResidentialProperty` / `residential_properties`
- `PropertySection` / `property_sections`
- `Unit` / `units`

Affected integration points:

- Property setup wizard controller actions that render steps 4 and 5.
- Property setup wizard serializers or prop builders (`Properties::Setup::BuildPreview`, `Properties::Setup::ValidateStep`).
- Vue/Inertia wizard summary, confirmation, and completed components (`Step4Summary.vue`, `Step5Confirm.vue`, `Step5Completed.vue`, `UnitsPreviewPanel.vue`).
- Existing i18n keys for summary labels, empty states, and counts.

Constraints:

- All reads must remain scoped to the current organization and current draft property.
- Authorization behavior does not change.
- Deleted units and deleted sections must not be counted in ordinary visible totals.
- The frontend must not be the source of truth for persisted counts.
- Units in this flow are expected to be associated with sections; the summary should not introduce property-level or estimated unit fallbacks.
- Units associated with soft-deleted sections must not be counted, even if the unit itself is not soft-deleted.
- `Properties::Setup::ValidateStep#validate_step_1` currently hard-requires `estimated_units` (blank/greater-than-0 checks). This validation must be removed together with the field, or step 1 becomes unsubmittable once the frontend stops sending it.
- The persisted unit total is not limited to steps 4/5: `Step5Completed.vue` (the post-confirmation completed view) and the shared `UnitsPreviewPanel.vue` also currently read `preview.property.estimated_units`. These are in scope for this change even though they render after confirmation, because they present the same unit total to the same user in the same flow.

## Goals / Non-Goals

**Goals:**

- Make summary and confirmation props database-backed and faithful to persisted records.
- Ensure "Datos de la propiedad" displays the saved property fields and real persisted structure/unit totals.
- Ensure unit counts reflect non-deleted units associated with sections in the current property, including manually created units.
- Remove the non-authoritative estimated unit count input and any summary/confirmation usage of that value.
- Ensure the user cannot reach confirmation while seeing stale totals after step 3 mutations.
- Add regression coverage for the 24-persisted-units versus 1-displayed-unit mismatch.

**Non-Goals:**

- Redesign the wizard UI.
- Change unit creation, section creation, import, or automatic generation behavior.
- Change property lifecycle confirmation rules.
- Add new user-facing copy unless an existing label cannot represent the corrected data.
- Change database schema.

## Decisions

1. Build summary/confirmation data from persisted Active Record relations.

   The backend should compute property, section, and unit summary props from the current organization-scoped draft property and its non-deleted section/unit associations. This avoids trusting client-side mode state, generated previews, or submitted counts. Alternative considered: fixing only the Vue display logic. That would be faster but would preserve the risk that stale props or preview arrays continue to drive confirmation totals.

2. Use one shared summary prop contract for steps 4 and 5.

   The confirmation step should reuse the same persisted summary contract as the review step, or derive from the same backend builder, so counts cannot diverge between "Resumen" and "Confirmar". Alternative considered: patch both screens separately. That increases duplication and makes future drift likely.

3. Keep frontend components presentational for authoritative counts.

   Vue components may format and group the summary data, but they must not recompute authoritative unit totals from partial local arrays when the backend provides persisted totals. Alternative considered: recomputing totals in Vue from nested preview props. That is acceptable for display-only subtotals if the full nested data is authoritative, but the top-level totals should still come from backend-provided persisted counts.

4. Remove estimated unit count from the setup form contract, its validation, and its prop key — not just from what is displayed.

   The estimated unit count does not add business value and can be confused with persisted unit totals in final review. Removing it avoids presenting non-authoritative values in "Datos de la propiedad", confirmation, and the completed view. This removal spans three layers that must move together: the step 1 form input, `ValidateStep#validate_step_1`'s required/greater-than-0 checks (otherwise step 1 cannot be submitted once the frontend stops sending the field), and the `estimated_units` key itself in `BuildPreview#property_summary` and any typed prop contract. The `estimated_units` key must not be silently repointed to hold a persisted count under its old name; components should read the already-available persisted `counts.units` (or an equivalently named authoritative field) instead, so no prop contract still labels a real count an "estimate." Alternative considered: keeping the field but relabeling it as a planning estimate. That still leaves a stale value in the flow and does not help the actual setup decision.

5. Refresh persisted summary props after unit mutations before review/confirmation.

   Navigation into steps 4 and 5 should load or reload persisted wizard props after step 3 create/edit/delete operations. Alternative considered: relying on existing page state after mutation. That is exactly where stale or partial data can leak into final review.

## Risks / Trade-offs

- Persisted relations may introduce extra queries -> mitigate with scoped eager loading or aggregate counts in the serializer/prop builder.
- Existing preview props may have different field names than summary props -> mitigate by adapting the summary view to the backend contract without changing unrelated preview behavior.
- Manual, automatic, and import modes may populate units differently -> mitigate by counting persisted non-deleted section-associated `Unit` records, independent of creation mode.
- Deleted records may be accidentally counted -> mitigate with explicit non-deleted scopes for both units and their sections, plus regression tests for soft-deleted units and soft-deleted sections.
- Removing estimated units may affect existing form props or tests -> mitigate by removing the field consistently from the step 1 form, `ValidateStep#validate_step_1`, the `BuildPreview#property_summary` prop key, translations, and tests.
- Scoping the fix only to `Step4Summary.vue`/`Step5Confirm.vue` would leave `Step5Completed.vue` and `UnitsPreviewPanel.vue` reading the same non-authoritative `estimated_units` field -> mitigate by including both in the frontend consumption tasks and regression tests.

## Migration Plan

No data migration is expected.

Implementation can be deployed as an application code change. Rollback is a code rollback only; persisted data remains unchanged.

## Open Questions

- None currently. The known example should be covered in tests: a draft property with 24 persisted non-deleted section-associated units must show 24 units in summary and confirmation.
