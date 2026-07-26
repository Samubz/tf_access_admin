## Context

The property setup wizard already persists property, section, and unit data and renders database-backed preview/confirmation summaries. Property catalog users now need a dedicated detail page that presents that same trusted persisted state without requiring them to enter the wizard just to inspect a property.

The requested UI follows `mockups/view-property-details/edit-view.png` for the main page layout: breadcrumb/header, summary cards, property facts, structure/section map, and recommended next actions. The mockup's right-side aside is intentionally deferred, so the detail page uses a single full-width column for now.

Affected models, services, database tables, and integration points:

- Models/tables: `ResidentialProperty` / `residential_properties`, `PropertySection` / `property_sections`, `Unit` / `units`, `Organization` / `organizations`.
- Controllers/serializers: admin residential property detail action, property detail props serializer, wizard preview/confirmation data builders, existing unit detail route props.
- Frontend: Inertia property detail page, shared wizard preview/tree components, route helpers, i18n keys in `es`, `en`, and `pt`.
- Authorization: property view/setup capabilities, unit manage/view capabilities, tenant scoping through the current organization.

## Goals / Non-Goals

**Goals:**

- Add a read-focused property detail page using persisted data.
- Reuse the wizard preview/confirmation data contract for structure, unit counts, completion context, and next actions.
- Match the main layout of `mockups/view-property-details/edit-view.png` as a single full-width column without implementing or reserving space for the right-side aside.
- Show the primary edit action only for `draft` and `created` properties.
- Keep the detail structure map read-only for sections; only unit rows expose the existing step 3 "Gestionar unidad" action.
- Hide the structure section when a property has no sections, and show default/null summary values where applicable.
- Populate "Próximos pasos recomendados" from the options shown in wizard step 5.
- Preserve tenant isolation, capability-based authorization, and existing unit detail behavior.

**Non-Goals:**

- Do not implement the mockup's aside/sidebar panels yet.
- Do not add root-section creation, section editing, section movement, or section actions to the detail page.
- Do not change property lifecycle transitions or wizard confirmation rules.
- Do not change wizard entry behavior for configured or active properties.
- Do not introduce a new unit-management page or new unit actions.
- Do not redesign the wizard preview beyond extracting/reusing it where needed.

## Decisions

1. Reuse wizard preview/confirmation builders for detail data.

   The property detail page should not recompute structure or unit counts differently from the wizard. Reusing the same server-side preview/confirmation data prevents drift in archived/soft-deleted filtering, tenant scoping, and persisted totals. Alternative considered: building a new detail-only serializer from raw associations. That risks repeating the stale-count issues already fixed in the wizard.

2. Implement the detail view as a dedicated Inertia page.

   A property detail page is a distinct read surface from setup. A dedicated page keeps view-only layout and actions clear, while still reusing shared components for preview trees and next-action cards. Alternative considered: rendering wizard step 5 as the property detail. That would overload confirmation semantics and make the read-only page harder to reason about.

3. Keep edit actions lifecycle-aware.

   `draft` and `created` properties show the primary edit action because they are still setup-editable states. `configured` and `active` do not show that primary edit action on the detail page. This change does not introduce any configured/active edit entry point and does not change wizard entry behavior.

4. Make the structure map read-only for sections.

   The detail view is not the manual structure builder. It must not show "Agregar sección raíz" or section row menus. Only unit rows expose the existing "Gestionar unidad" action from wizard step 3, linking to the existing unit detail page. The detail mode must not inherit wizard unit edit/delete actions from `UnitTreeRow`. Alternative considered: reusing the builder component unchanged. That would leak creation/editing affordances into a read-focused surface.

5. Hide the structure section when there are no sections.

   A property with no sections should not render an empty structure map. Summary cards and facts should still render, using default or null values such as `0` for counts and empty/null presentation for unavailable values. Alternative considered: showing an empty structure card. That adds noise and makes the page feel incomplete when "no sections" is a valid state.

6. Use step 5 options for recommended next actions.

   "Próximos pasos recomendados" means the follow-up options shown in the wizard step 5 completion/confirmation context, not the confirmation controls themselves. The detail page should reuse those options where authorized and applicable.

7. Defer aside implementation.

   The mockup's aside includes configuration summary, preview, activity, and quick data panels. This change implements the main content as one full-width column and does not build or reserve an empty aside region. This keeps the first detail view focused and avoids duplicating activity/history requirements before they are specified.

8. Repoint the existing wizard `property_detail` next-action to the new detail route.

   `Step5Completed.vue` already defines a next-action keyed `property_detail` whose `href` currently points to `/admin/residential_properties/:id/edit` (the setup wizard), not a real detail page. Its label and copy already describe viewing the property, so once the detail page exists, this action must link to it instead of to `/edit`. Alternative considered: leaving the existing action pointed at `/edit` and only linking to the new detail page from the catalog. Rejected because it leaves a wizard action mislabeled relative to where it actually navigates.

9. Internationalize all visible copy.

   New page labels, actions, empty states, status badges, and next-action copy need locale keys under a property-detail namespace in `es`, `en`, and `pt`.

10. Structure map rows render collapsed by default.

    Root sections (towers/roots) load with their subtree closed, requiring an explicit click to expand. Alternative considered: expanded by default, mirroring the wizard's `UnitSectionTreeRow`. Rejected after review: a property with several towers/floors becomes a long, noisy scroll if everything opens at once on a read-only page whose first job is a quick glance, not editing.

11. `manage_units` next-action has no destination in this change.

    While implementing the shared next-actions list (Decision 6), no dedicated units-management HTML page exists in the app: `/admin/residential_properties/:id/units` (`index`) is a JSON-only endpoint consumed only by a controller test, never by any frontend page. The `manage_units` action therefore ships with `href: undefined` — permanently disabled, identically to `import_owners`/`configure_residents` — rather than linking users to a raw JSON response. Building an actual units-management page is out of scope here and left for a future change.

## Risks / Trade-offs

- [Risk] Detail counts diverge from wizard counts. -> Mitigate by reusing the wizard persisted preview/confirmation data contract.
- [Risk] Users expect section editing from the structure map because it resembles the builder. -> Mitigate by removing section actions and root creation from the detail view entirely.
- [Risk] Users may expect configured/active properties to be editable from detail. -> Mitigate by hiding the primary edit action for those statuses and keeping wizard behavior unchanged.
- [Risk] Shared preview components may include builder-only controls. -> Mitigate with explicit read-only/detail mode props and tests proving section controls are absent.
- [Risk] Shared unit row components may include edit/delete actions. -> Mitigate with a detail-specific mode that exposes only "Gestionar unidad".
- [Risk] Cross-tenant data leakage through nested preview props. -> Mitigate with property-scoped queries and controller/policy tests.
- [Risk] Repointing the existing `property_detail` next-action could regress the current `/edit` shortcut some users rely on. -> Mitigate by keeping `reopen_setup` as the dedicated action for reopening the wizard, since that already exists as a separate next-action.

## Migration Plan

- Add a `:show` route/action for `residential_properties` (none exists today; current routes only cover `index`, `new`, `create`, and member `archive`).
- Reuse existing property, section, unit, and wizard preview data; no data migration is required.
- Ship the detail page with feature-complete main content and hidden/deferred aside.
- Rollback removes the route/page and restores prior catalog navigation; no persisted data rollback is needed.

## Open Questions

- None for this change. The aside is explicitly deferred and should be specified separately before implementation.
- Resolved: the existing `property_detail` next-action in wizard step 5 will be repointed to the new detail route instead of `/edit` (see Decision 8).
- Open (deferred to a future change): a real units-management page for the `manage_units` next-action. Until then, that action is permanently disabled on both the wizard completion screen and the detail page (see Decision 11).
