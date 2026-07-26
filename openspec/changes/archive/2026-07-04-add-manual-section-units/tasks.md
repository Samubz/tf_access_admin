## 1. Backend Unit Mutations

- [x] 1.1 Inspect existing `Admin::PropertySetup::WizardController`, `Admin::ResidentialProperties::UnitsController`, `Units::Create`, `Units::Update`, and `Units::SoftDelete` patterns to mirror routing, authorization, and result handling.
- [x] 1.2 Add wizard-scoped routes/actions for manual unit create, multiple create, update, and soft delete under the current draft property.
- [x] 1.3 Resolve submitted `property_section_id` through the current draft property and organization before invoking unit services, rejecting requests with no eligible section.
- [x] 1.4 Implement manual multiple unit creation with the same generator semantics and limits as manual multiple sections: `cantidad`, optional `prefijo`, `formato`, and a live preview-matching identifier list.
- [x] 1.5 Persist manual multiple unit creation inside an all-or-nothing transaction and return a descriptive batch alert if any planned unit fails.
- [x] 1.6 Delegate individual and multiple manual unit creation to `Units::Create` without silently creating duplicates.
- [x] 1.7 Delegate unit edits to `Units::Update` while permitting only `area_m2`, `display_name`, `unit_type`, and `identifier`; regenerate server-derived `code` when `identifier` changes and reject the identifier update if the regenerated code collides.
- [x] 1.8 Delegate unit deletion to `Units::SoftDelete`, show the generic related-record warning before request submission, do not block on related records, and ensure deleted units are excluded from subsequent wizard preview props.
- [x] 1.9 Require `manage_units` permission for wizard draft unit mutations.

## 2. Wizard Props and Preview Data

- [x] 2.1 Extend property setup serialization/preview data to include non-deleted units grouped under their assigned sections for step 3.
- [x] 2.2 Expose persisted unit IDs and enough unit fields for preview rows and edit dialogs without leaking organization, property, lifecycle, or code mutation fields.
- [x] 2.3 Ensure manual unit mutations reload or refresh wizard props so the preview reflects persisted create, edit, and soft-delete results.
- [x] 2.4 Preserve existing automatic generation preview behavior for quick structures.
- [x] 2.5 Select automatic mode by default on first-time quick setup, and manual mode by default when editing/resuming persisted units.

## 3. Frontend Forms and Interactions

- [x] 3.1 Add Zod schemas under `app/javascript/lib/schemas/` for manual individual unit, manual multiple unit, and unit edit dialogs.
- [x] 3.2 Build the add-unit dialog with individual and multiple modes mirroring manual section creation controls, excluding `display_name` from multiple mode, wired through VeeValidate and server error merging.
- [x] 3.3 Build the unit edit dialog for `area_m2`, optional `display_name`, `unit_type`, and `identifier`.
- [x] 3.4 Add unit delete confirmation using the existing confirm dialog pattern, include the special related-record warning, and send no request until confirmed.
- [x] 3.5 Update `Step3Units.vue` to add a new `manual` units mode available when the property has at least one eligible section.
- [x] 3.6 Show descriptive alert feedback when manual multiple creation rolls back.

## 4. Shared Preview UI

- [x] 4.1 Reuse/adapt the `ManualSectionForm` and `ManualSectionTreeRow` visual pattern for step 3 unit-management mode.
- [x] 4.2 In unit-management mode, render section rows with only the add-unit action for eligible unit containers.
- [x] 4.3 Render unit rows under sections with a dropdown containing exactly edit and delete actions.
- [x] 4.4 Keep step 2 manual builder behavior unchanged, including section-only preview and section action dropdowns.
- [x] 4.5 Add empty/zero-unit states for sections without units in step 3.
- [x] 4.6 Handle draft properties with no eligible sections by directing the user to the existing single-creation or import unit modes instead of manual mode.

## 5. Internationalization

- [x] 5.1 Add `es`, `en`, and `pt` translations for manual unit mode labels, dialogs, validation messages, dropdown actions, confirmations, empty states, and errors.
- [x] 5.2 Ensure all new Rails flash/errors and Vue text use i18n keys.

## 6. Tests and Validation

- [x] 6.1 Add focused controller/service tests for wizard-scoped manual unit create, all-or-nothing multiple create, edit, and soft delete.
- [x] 6.2 Add tests for tenant isolation, missing/blank section IDs, foreign section/unit IDs, ineligible sections, duplicate identifiers, code regeneration on identifier edit, code-collision rejection, `manage_units` authorization, and soft-delete uniqueness release.
- [x] 6.3 Add frontend type/schema validation coverage or run the focused frontend type check for touched Vue/TypeScript code.
- [x] 6.4 Run targeted Rails tests for unit services and property setup wizard behavior.
- [x] 6.5 Run `openspec validate add-manual-section-units --strict`.
- [x] 6.6 Run `graphify update app` after implementation changes.
