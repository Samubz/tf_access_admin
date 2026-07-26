## Why

Property setup now persists enough structured data to support a dedicated property detail view instead of sending users back into setup or operational lists for basic inspection. Users need a read-focused page that shows the same persisted preview and completion context they already trust in the wizard, while keeping editing entry points constrained by lifecycle status.

## What Changes

- Add a property detail view following `mockups/view-property-details/edit-view.png` for the main content area.
- Show property details, summary cards, recommended next actions, and the already-created wizard structure/unit preview on the detail view.
- Reuse persisted data contracts from the wizard preview and confirmation step so counts, property details, sections, units, and next actions remain faithful to the database.
- Add lifecycle-aware actions:
  - show the primary edit option only for `draft` and `created` properties;
  - do not add an "Agregar sección raíz" action on the detail view.
- Render structure/section rows as read-only on the detail view; only unit rows may expose actions.
- Reuse the step 3 unit action for each unit row: "Gestionar unidad", linking to the existing unit detail page.
- Show step 5 next actions in the "Próximos pasos recomendados" section.
- If the property has no sections, hide the property structure section and show default/null summary values such as `0` or empty values where applicable.
- Defer the mockup's right-side aside/sidebar panels for a later change.

## Capabilities

### New Capabilities

- `property-detail-view`: Defines the read-focused property detail page, its layout, persisted data contract, lifecycle-aware actions, and structure/unit preview behavior.

### Modified Capabilities

- `property-setup-wizard` (step 5 next actions): repoint the existing `property_detail` next-action in `Step5Completed.vue` from `/admin/residential_properties/:id/edit` to the new property detail route, since its label already promises a detail view.

## Bounded context

Affected domains and integration points:

- Residential property catalog/detail navigation.
- Property setup wizard preview and confirmation data.
- Property sections and units preview tree.
- Existing unit detail route used by the wizard step 3 manage-unit action.
- Authorization for property viewing, setup editing, and unit management.

Affected models, services, and tables:

- Models: `ResidentialProperty`, `PropertySection`, `Unit`, `Organization`.
- Services/serializers/controllers: property detail controller/serializer, setup preview/confirmation serializers, policy checks, route helpers.
- Tables: `residential_properties`, `property_sections`, `units`, `organizations`.

Dependencies on other OpenSpec changes:

- Depends on the archived `enable-wizard-editing-created-state` work, especially editable statuses, wizard step 5 completion behavior, hidden archived records in wizard previews, and the step 3 manage-unit action.

Tenant isolation and authorization impact:

- Property detail reads MUST remain scoped to the current organization and property authorization.
- Cross-organization properties, sections, or units MUST NOT be returned in props.
- The edit action and unit manage action MUST be shown only when the authorized actor has the required capability for that specific property/unit context.

## Impact

- Adds a new full-width, single-column Inertia page for property detail, along with a new `show` route/action (no `:show` route currently exists for `residential_properties`).
- Repoints the existing `property_detail` next-action in the wizard step 5 completion screen (`Step5Completed.vue`) to the new detail route.
- Reuses or extracts wizard preview/confirmation serializers/components instead of rebuilding a divergent summary.
- Adds frontend i18n keys for the detail page labels, actions, empty states, and status copy in `es`, `en`, and `pt`.
- Adds controller, serializer, policy, and Vue/TypeScript coverage for the new detail view behavior.

## Non-goals

- Do not implement the right-side aside/sidebar from the mockup in this change.
- Do not add section creation, section edit, section move, or root-section creation controls to the detail view.
- Do not expose section row actions in the structure map.
- Do not inherit wizard unit edit/delete actions into the detail view structure map.
- Do not create new unit-management behavior beyond linking to the existing unit detail page action.
- Do not change wizard entry behavior, step 5 business rules, or lifecycle transitions.
- Do not introduce new status values or new authorization capabilities unless an existing policy gap makes that unavoidable.
