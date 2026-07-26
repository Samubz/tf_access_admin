## Context

The setup wizard currently persists draft property, section, and unit data across five steps, then confirms the property into `configured`. Existing contracts also allow `configured` properties to continue receiving section and unit mutations, but they do not define a post-wizard state where property identity and structure can remain editable before final confirmation.

This change introduces `created` as a completed-but-editable setup state. It also keeps `configured` and `active` properties editable through the wizard for now, using different reset semantics to protect persisted operational history.

Affected models and tables:

- `ResidentialProperty` / `residential_properties`
- `PropertySection` / `property_sections`
- `Unit` / `units`

Affected integration points:

- Property setup wizard controller actions and routes for existing properties.
- Property setup serializers/prop builders that determine available modes and editability.
- Property setup services for draft initialization, step persistence, confirmation, and destructive structure reset.
- Manual section and manual unit wizard components.
- `Properties::Setup::BuildPreview` (persisted summary/preview counts) — must also exclude archived sections/units, not only soft-deleted ones.
- Existing `PropertySections::Archive` and `Units::Archive` (status-only, non-destructive) and `Units::Reactivate` (unaffected, remains an ordinary-admin capability outside the wizard).
- Existing `PropertySections::Move` (section move-to-parent), now invoked from a new wizard-native action instead of the retired standalone structure page.
- The standalone, non-wizard structure page (`Admin::ResidentialProperties::StructuresController`, `admin/residential_properties/structure.vue`) and its exclusive-use components (`SectionTree.vue`, `SectionMoveDialog.vue`, `usePropertySectionStructureState`, `usePropertySectionSubmit`) — removed.
- `Admin::ResidentialProperties::PropertySectionsController` (the structure page's section-mutation controller: create/update/move/archive) — removed; its underlying services are preserved and reused by new wizard-native actions.
- `Admin::PropertySectionsController#edit` (organization-wide flat section directory) — its redirect target changes from the removed structure page to the setup wizard.
- i18n keys for destructive reset confirmation and final created/confirmed choices.

## Goals / Non-Goals

**Goals:**

- Add `created` as a lifecycle state for completed wizard output that remains editable through the wizard.
- Let step 5 choose between leaving the property `created` or confirming it as `configured`, but only offer the `configured` choice when the current status is earlier than `configured` (`draft` or `created`); `configured`/`active` edit sessions only offer a plain save that preserves the current status.
- Allow `created`, `configured`, and `active` properties to edit property identity fields, property type, building format, manual sections, and manual units from wizard step 1.
- Define property identity fields as `address_line`, `city`, `country`, `name`, `property_type`, `region`, and `timezone`.
- Derive `normalized_name` from `name`, and derive property `code` from property type abbreviation plus `normalized_name` using the existing implemented code-generation convention.
- Reject edits that generate a colliding property `code` and tell the client to change the property name.
- Preserve lifecycle direction: `configured` can only transition to `active`, and `active` can only transition to `archived`.
- Require explicit confirmation before resetting existing sections/units when draft/created/configured/active setup changes property type or structure mode (building format has no independent value to trigger on; see Decision 8).
- Use hard reset (`really_destroy`) for draft properties. For created/configured/active properties, remove sections/units via soft-delete when they have no operational history, or via archive-with-confirmation when they (or a descendant) do — see Decision 9.
- Restrict created/configured/active wizard edit sessions to manual section and manual unit modes.
- Hide archived sections and units (and units under an effectively-archived section) from all wizard views and persisted summary/preview counts.
- Add a "manage unit" action to each unit row's menu in wizard step 3 that navigates to that unit's existing, non-wizard detail page.
- Add "move section to a different parent" as a native wizard capability (step 2), reusing the existing `PropertySections::Move` service.
- Retire the standalone, non-wizard structure page and its dedicated mutation controller now that the wizard covers section/unit management (including move and archive) for every editable status; update the one other entry point that linked to it (the organization-wide flat section directory's edit action) to link into the wizard instead.

**Non-Goals:**

- Do not redesign the five-step wizard.
- Do not enable quick automatic generation for already created/configured/active properties.
- Do not change ordinary admin CRUD outside the setup wizard.
- Do not allow inactive or archived properties to mutate through setup.

## Decisions

1. Use `created` for the editable post-wizard state and keep `configured` as confirmed.

   `created` names the business state where setup exists but is still revisable. `configured` remains the confirmed setup state already present in the system. Alternative considered: reusing `draft` after wizard completion. That would blur "in progress" and "completed but editable" and make catalog/status badges less meaningful.

2. Make destructive structure reset explicit and all-or-nothing.

   If a draft, created, configured, or active property already has sections or units and the user changes property type or structure mode, the UI must show a confirmation dialog before the backend resets the configured structure. The backend still performs the reset transactionally and tenant-scoped, so the client confirmation is not the only guard. Alternative considered: silently clearing dependent records during step navigation. That is too surprising for a setup flow with persisted data.

3. Keep configured and active editable through the wizard for now.

   Product direction is to allow `created`, `configured`, and `active` properties to reopen the wizard at step 1 and edit property identity fields, property type, building format, manual sections, and manual units. The safety boundary is the reset behavior and confirmation requirement for structure-affecting changes. A stricter post-confirmation edit policy was considered and rejected for now because the business wants editability across these statuses.

4. Limit created/configured/active edit sessions to manual modes.

   Quick automatic structure and unit generation remain first-time setup aids. Once a property is created/configured/active, edits happen through manual section and manual unit management to avoid accidental regeneration or orphaning of persisted records.

5. Use status-specific reset semantics, with operational history overriding soft-delete to archive.

   A draft property can `really_destroy` sections and units during a confirmed reset because draft setup is treated as not yet having relevant business history. Created, configured, and active properties remove sections/units during reset using the same operational-history rule as Decision 9: soft-delete when there is no operational history anywhere in the affected section/unit, archive (with explicit confirmation) when there is. Alternative considered: soft-delete everything unconditionally for created/configured/active. Rejected per Decision 9 — soft-deleting a unit with real `unit_ownerships`/`lease_contracts`/`unit_occupancies`/`visits` would silently hide live operational history.

6. Keep manual section deletion separate from destructive reset.

   Manual deletion of a single section is a scoped manual-structure operation, not a structure reset. If that section has units, the section and its associated units are removed together using the same operational-history rule as Decision 9 (soft-delete or archive), and unrelated sections/units are left unchanged.

7. Treat code collisions as validation failures.

   Property `code` generation must reuse the existing implemented convention. If a name or property type edit would generate a duplicate property code, reject the edit and return an actionable client error instructing the user to change the property name.

8. Building format has no independent value; it is derived from property type.

   Per the existing `property-structure-format` capability, `StructureFormatResolver` derives the recommended format entirely from `property_type` (with an optional `skip_top_level` toggle that lives in `quick_structure`/structure-mode configuration, not a separate persisted field). There is no independently stored "building format" to diff for reset detection. Reset triggers are therefore `property_type` and `structure_mode` only; "building format" is not a third, independent trigger. Earlier wording that listed it as a separate trigger is corrected here and in the specs.

9. Removing a unit or section with operational history requires archive-with-confirmation instead of soft-delete; removal without history is a direct soft-delete.

   Before removing a unit (via manual delete or structure reset), check whether it has any `unit_ownerships`, `lease_contracts`, `unit_occupancies`, or `visits` records. If none exist, soft-delete it directly (existing `Units::SoftDelete`). If any exist, the removal must go through `Units::Archive` (status-only, non-destructive) behind an explicit user confirmation, since archiving a unit through this flow is intended to be effectively one-way in practice (see Decision 10). The same check applies to a section, scoped to that section's own units only: if any of them has operational history, the section and its own units must be archived via `PropertySections::Archive`/`Units::Archive` rather than soft-deleted, all-or-nothing. This does not need to look at a child section's units transitively, because a section with child sections cannot be removed as a single unit anyway (`dependent: :restrict_with_error` on `:children` already blocks that until the children are removed individually) — the structure reset instead removes each section bottom-up (children first, then roots), applying this same per-section check to each one individually. Alternative considered: always soft-delete for created/configured/active. Rejected because it can silently orphan live tenant/owner relationships on an operational property.

10. Retire the standalone structure page and its dedicated mutation controller; keep shared services and shared components.

    Removed: `Admin::ResidentialProperties::StructuresController`, `admin/residential_properties/structure.vue`, and the components/composables used exclusively by that page (`SectionTree.vue`, `SectionMoveDialog.vue`, `usePropertySectionStructureState`, `usePropertySectionSubmit`). Also removed: `Admin::ResidentialProperties::PropertySectionsController` (the page's section create/update/move/archive controller) — its services (`PropertySections::Create`, `PropertySections::Update`, `PropertySections::Move`, `PropertySections::Archive`) are preserved and invoked from new wizard-native controller actions instead, following the existing pattern where the wizard already owns its own section/unit mutation endpoints rather than delegating to the non-wizard nested controllers.

    Not removed: `BulkUnitsImportDrawer.vue` (genuinely shared, confirmed via `useBulkUnitsImportDrawer.ts` still hitting the nested `bulk_imports` route), `PropertySections::TreeBuilder` (shared with `BuildPreview`), and `Admin::ResidentialProperties::UnitsController`'s `index`/`show`/`update`/`restore` actions (the unit detail page depends on them). That controller's `create`/`move`/`archive` actions, whose only caller was the removed structure page, became dead code once the wizard gained its own equivalent actions and were removed in the same pass, along with their now-dangling `structure_path` redirect target.

    Correction found during implementation: `StructureForm.vue` was originally assumed to be shared with the wizard, but no such import actually existed in `Step2Structure.vue`/`Step3Units.vue` — it was only reachable through the deleted structure page. It was removed too, along with its exclusive sub-components (`SectionTreeNode.vue`, `SectionTreeUnit.vue`, `SectionStatusBadge.vue`) and the orphaned `lib/breadcrumbs/property_structure.ts` helper.

    `Admin::PropertySectionsController#edit` (the organization-wide flat section directory) is updated to redirect into the setup wizard instead of the removed structure page.

    Alternative considered: keep the standalone structure page alongside the wizard. Rejected — it would duplicate section/unit mutation logic in two places (the exact drift risk Decision 2 in the persisted-summary work already warned against) and contradicts the stated direction that created/configured/active editing happens through the wizard.

11. Reuse existing archive/reactivate services as-is; do not cascade archived status, and do not restrict reactivation.

    `PropertySections::Archive` and `Units::Archive` are used unmodified: archiving a section does not write `status = archived` onto its descendants (its documented behavior already relies on computed `effective_status`, not a cascaded write). The wizard achieves "archived items are hidden from the wizard" by filtering on `effective_status` (self or nearest archived ancestor) when building wizard trees/previews/counts, not by changing what `Archive` persists. `Units::Reactivate` is untouched and remains available through ordinary admin unit management outside the wizard; the wizard itself simply never exposes a reactivate action, and never re-surfaces an archived unit/section for editing once archived through this flow.

12. Retire the standalone property-edit page too; accept a coverage gap for `inactive` properties.

    `Admin::ResidentialPropertiesController#edit`/`#update` and `Properties::Update` only ever edited the same identity fields the wizard now covers for `draft`/`created`/`configured`/`active` (`edit.vue` never actually exposed a status selector despite the controller technically permitting `:status`). Once retired, entry points that linked to it (`residential_properties/index.vue`'s row action, `PersonOccupanciesTab.vue`/`PersonOwnershipsTab.vue`'s property-name links) redirect into the wizard instead. `inactive` properties are the one gap: the wizard's `ensure_wizard_editable!` only allows `OPERABLE` statuses (draft/created/configured/active), so an `inactive` property loses its only field-editing path, and no reactivation control exists in the UI today to get it back to `active` first. Explicitly accepted rather than solved here (see Non-goals) — extending wizard editability to `inactive`, or building a real activate/deactivate UI, is future work. `archived` properties lose nothing (the old edit page already disabled the form for them).

## Risks / Trade-offs

- [Risk] Adding a lifecycle status can break status validations, filters, badges, or enums. -> Mitigate with model, serializer, policy, and catalog tests for `created`.
- [Risk] Structure reset can remove too much data. -> Mitigate with a dedicated service scoped to current organization/property, hard reset only for draft, operational-history-aware soft-delete/archive for created/configured/active (Decision 9), and tests for all-or-nothing removal of sections and associated units.
- [Risk] Soft-deleting a unit/section with real operational history (`unit_ownerships`, `lease_contracts`, `unit_occupancies`, `visits`) would silently hide live tenant/owner relationships on an operational property. -> Mitigate with the operational-history check in Decision 9: archive (with explicit confirmation) instead of soft-delete whenever such history exists anywhere in the affected section/unit.
- [Risk] Frontend mode availability may diverge from backend enforcement. -> Mitigate by enforcing status/mode rules server-side and reflecting them in explicit props.
- [Risk] Property `code` and `normalized_name` may diverge from `name`. -> Mitigate by reusing the existing normalization/code pattern when `name` or `property_type` changes.
- [Risk] Wizard edits could accidentally move properties backward in lifecycle. -> Mitigate with transition guards and tests for `configured -> active`, `active -> archived`, and rejected `active -> configured` / `configured -> created` transitions.
- [Risk] A generated property `code` may collide. -> Mitigate by rejecting the edit and returning an actionable client error telling the user to change the property name.
- [Risk] Retiring the standalone property-edit page leaves `inactive` properties with no way to edit their basic fields. -> Explicitly accepted (Decision 12) rather than mitigated in this change; flagged as follow-up work.
- [Risk] Step 5 could offer a "confirm as configured" control that is meaningless or rejected for already-`configured`/`active` properties. -> Mitigate by only rendering that control when status is earlier than `configured` (Goals, Decision 1's transition table).
- [Risk] Wizard summary/preview counts (`BuildPreview`) could still count archived sections/units, reintroducing a mismatch like the one fixed in the persisted-summary work. -> Mitigate by extending the same visibility filter (now `effective_status`-aware, not just `deleted_at`-aware) to `BuildPreview`.
- [Risk] Removing the standalone structure page and its dedicated controller could silently break another entry point that still links to it. -> Mitigate by updating the one other known caller (`Admin::PropertySectionsController#edit`) to redirect into the wizard, and by removing `Admin::ResidentialProperties::UnitsController`'s now-orphaned `create`/`move`/`archive` actions in the same pass so no dangling `structure_path` redirect remains.
- [Risk] Retiring the structure page drops "move unit to a different section," which had no other caller either. -> Accepted for now; only "move section to a different parent" is being carried into the wizard (Decision 10), per explicit product direction.

## Migration Plan

- Add `created` to the property status contract and any status enum/catalog.
- Backfill is not required for existing properties unless product decides some existing `configured` records should become `created`; by default existing statuses remain unchanged.
- Deploy backend status support before relying on frontend controls that emit `created`.
- Rollback requires preventing new `created` transitions first, then converting any `created` properties to `configured` or `draft` by an explicit data decision.

## Open Questions

- None for the contract. The implementation should treat "confirmada" as the existing `configured` status unless the product later renames that status in UI copy.
