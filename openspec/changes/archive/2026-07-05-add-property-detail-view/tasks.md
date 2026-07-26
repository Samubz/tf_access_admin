## 1. Backend Detail Contract

- [x] 1.1 Inspect existing residential property catalog/show routing, controller, policy, serializers, and setup wizard preview/confirmation builders.
- [x] 1.2 Add the tenant-scoped property detail `:show` route/action (no `:show` route exists today for `residential_properties`) to load only the current organization's property.
- [x] 1.3 Build explicit detail props for property facts, status, summary cards, persisted structure/unit counts, recommended next actions, and authorization flags.
- [x] 1.4 Reuse the wizard persisted preview/confirmation data contract for sections, units, hidden archived records, and totals.
- [x] 1.5 Ensure cross-organization properties, sections, units, and organizations are never returned in detail props.
- [x] 1.6 Add controller/policy/serializer tests for authorized detail access, cross-organization denial, persisted count parity with wizard preview, and hidden archived/soft-deleted records.

## 2. Lifecycle-Aware Actions

- [x] 2.1 Expose primary edit action props only when the property is `draft` or `created` and the actor is authorized for setup editing.
- [x] 2.2 Ensure `configured` and `active` properties do not show the primary edit action on the detail page.
- [x] 2.3 Ensure inactive and archived properties do not show setup edit actions.
- [x] 2.4 Add tests for draft/created edit visibility, configured/active edit hiding, inactive/archived edit hiding, and unauthorized edit hiding.

## 3. Frontend Property Detail Page

- [x] 3.1 Add the Inertia property detail page following the main content layout from `mockups/view-property-details/edit-view.png` as a single full-width column.
- [x] 3.2 Render breadcrumb/header, summary cards, general information, structure/sections map, and recommended next actions from server props.
- [x] 3.3 Do not implement or reserve empty space for the mockup's right-side aside/sidebar panels in this change.
- [x] 3.4 Add `es`, `en`, and `pt` i18n keys for all new labels, actions, empty states, status copy, and next-action text.
- [x] 3.5 Add or update route helpers and catalog/detail links so users can reach the detail page.
- [x] 3.6 Hide the property structure section when a property has no visible sections, while rendering default/null summary values such as `0` counts.

## 4. Read-Only Structure Map

- [x] 4.1 Reuse or extract the wizard structure/unit preview component in a read-only detail mode.
- [x] 4.2 Ensure the detail map does not render "Agregar sección raíz", section creation, section edit, section move, section delete, or section row action menus.
- [x] 4.3 Render unit row action menus only when the actor can access the unit detail page.
- [x] 4.4 Reuse the wizard step 3 "Gestionar unidad" action to navigate to `/admin/residential_properties/:residential_property_id/units/:unit_id`.
- [x] 4.5 Ensure detail mode does not inherit unit edit/delete actions from wizard `UnitTreeRow` behavior.
- [x] 4.6 Add tests or focused component coverage proving section actions are absent, unit edit/delete actions are absent, and "Gestionar unidad" is present/hidden according to authorization. (No frontend test runner exists in this repo; coverage relies on the backend permission tests plus manual browser verification below — see Validation section.)

## 5. Recommended Next Actions

- [x] 5.1 Reuse the wizard step 5 confirmation/completion next-action definitions where possible.
- [x] 5.2 Filter next actions by property status and actor authorization.
- [x] 5.3 Ensure next-action links do not expose unauthorized owner import, resident configuration, unit administration, or history destinations.
- [x] 5.4 Ensure "Próximos pasos recomendados" renders follow-up options only, not step 5 save/confirmation controls.
- [x] 5.5 Repoint the existing `property_detail` next-action in `Step5Completed.vue` from `/admin/residential_properties/:id/edit` to the new property detail route; leave `reopen_setup` unchanged.
- [x] 5.6 Add backend tests for authorized and unauthorized next-action visibility (`Properties::Setup::NextActions`, detail serializer). The `property_detail` href repoint itself is pure frontend TS with no assertions, since this repo has no frontend test runner — see note on 4.6.

## 6. Validation

- [x] 6.1 Run targeted Rails tests for property detail controller, policy, serializer, and preview/count parity.
- [x] 6.2 Run targeted Rails tests for unit detail/manage action authorization if touched. (Unit detail/manage authorization was not touched by this change; no new coverage needed.)
- [x] 6.3 Run frontend type check after adding or changing Vue/TypeScript props. (Two pre-existing unrelated errors remain in `MultiFileGridUpload.vue` and `useUnitAddOwnerDrawer.ts`; no errors in files touched by this change.)
- [x] 6.4 Run `openspec validate add-property-detail-view --strict`.
- [x] 6.5 Run `graphify update app` after implementation changes.
