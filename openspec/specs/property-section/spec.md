# property-section Specification

## Purpose

Define the tenant-safe hierarchical, lifecycle, service, tree, and authorization contract for structural sections within a residential property.

## Requirements

### Requirement: Property section belongs to organization and property

The system SHALL require every `PropertySection` to belong to exactly one organization and one residential property whose organization matches the section organization.

#### Scenario: Section derives organization from property

- **GIVEN** property P belongs to organization O
- **WHEN** an authorized actor creates a section under P
- **THEN** the section references P and O
- **AND** organization is derived from trusted property context

#### Scenario: Section without property is rejected

- **WHEN** section creation has no valid residential property
- **THEN** creation is rejected
- **AND** no section is persisted

#### Scenario: Section without organization is rejected

- **GIVEN** no organization can be derived from the property context
- **WHEN** section creation is attempted
- **THEN** creation is rejected

#### Scenario: Section and property organization mismatch is rejected

- **GIVEN** P belongs to organization O
- **WHEN** a section attempts to reference organization Q
- **THEN** validation rejects the section

### Requirement: Property section may have one parent section

The system SHALL allow a section to be either a root section with no parent or a subsection whose parent is a root section in the same property.

#### Scenario: Root section is created

- **GIVEN** active property P
- **WHEN** an authorized actor creates `Torre A` without a parent
- **THEN** the section is a root of P

#### Scenario: Subsection is created

- **GIVEN** active section `Torre A` in P
- **WHEN** an authorized actor creates `Piso 1` with `Torre A` as parent
- **THEN** `Piso 1` is persisted as its child

#### Scenario: Third hierarchy level is rejected

- **GIVEN** an active hierarchy `Etapa 1 -> Edificio 3`
- **WHEN** an authorized actor attempts to create `Piso 1` under `Edificio 3`
- **THEN** the operation is rejected
- **AND** no third hierarchy level is persisted

### Requirement: Parent section must belong to same property

The system MUST require a section and its parent to belong to the same residential property.

#### Scenario: Parent from another property is rejected

- **GIVEN** parent S belongs to property P
- **AND** a new section belongs to property Q
- **WHEN** S is submitted as parent
- **THEN** creation or movement is rejected
- **AND** no cross-property hierarchy is created

### Requirement: Parent section must belong to same organization

The system MUST require a section and its parent to belong to the same organization.

#### Scenario: Parent from another organization is rejected

- **GIVEN** parent S belongs to organization O
- **AND** the target section context belongs to Q
- **WHEN** S is submitted as parent
- **THEN** the operation is rejected without exposing inaccessible hierarchy data

### Requirement: Property section hierarchy is limited to two levels

The system SHALL enforce a maximum hierarchy depth of two levels: root section and subsection.

#### Scenario: Root section has depth one

- **GIVEN** section S has no parent
- **WHEN** S is evaluated in the hierarchy
- **THEN** S is treated as a root section

#### Scenario: Subsection has root parent

- **GIVEN** root section R belongs to property P
- **WHEN** section S is created with R as parent
- **THEN** S is accepted as a subsection
- **AND** S has no children below it by default

#### Scenario: Subsection cannot receive child section

- **GIVEN** subsection S already has a parent
- **WHEN** an actor attempts to create another section under S
- **THEN** the operation is rejected
- **AND** the hierarchy remains limited to two levels

#### Scenario: Move under subsection is rejected

- **GIVEN** subsection S already has a parent
- **AND** section X belongs to the same property
- **WHEN** X is moved under S
- **THEN** the move is rejected
- **AND** no third hierarchy level is created

### Requirement: Property section hierarchy cannot contain cycles

The system MUST prevent direct and indirect cycles at model, service, and persistence boundaries.

#### Scenario: Section cannot parent itself

- **GIVEN** existing section S
- **WHEN** S is moved with `parent_id = S.id`
- **THEN** the move is rejected
- **AND** the hierarchy is unchanged

#### Scenario: Section cannot move below its child

- **GIVEN** hierarchy `A -> B`
- **WHEN** A is moved under B
- **THEN** the move is rejected
- **AND** no cycle is persisted

#### Scenario: Valid two-level hierarchy remains traversable

- **GIVEN** an acyclic hierarchy with roots and subsections
- **WHEN** it is traversed
- **THEN** every node is reached at most once
- **AND** no node appears below the second level

### Requirement: Property section name is normalized

The system SHALL derive `normalized_name` from the section name using canonical whitespace, Unicode, and case-insensitive normalization.

#### Scenario: Name is normalized before persistence

- **WHEN** an actor submits `  Piso   Norte `
- **THEN** the display name is trimmed
- **AND** `normalized_name` stores the canonical comparison value

#### Scenario: Blank normalized name is rejected

- **WHEN** a section name normalizes to blank
- **THEN** the operation is rejected with a name error

### Requirement: Property section name is unique under same parent

The system SHALL enforce normalized-name uniqueness among non-deleted sibling sections in the same property and parent context, including root sections.

#### Scenario: Duplicate sibling name is rejected

- **GIVEN** parent A has child `Piso 1`
- **WHEN** another child under A is submitted as ` piso   1 `
- **THEN** the operation is rejected
- **AND** no duplicate sibling is persisted

#### Scenario: Duplicate root name is rejected

- **GIVEN** P has root section `Torre A`
- **WHEN** another root in P is submitted as `torre a`
- **THEN** the operation is rejected

#### Scenario: Concurrent duplicate sibling is protected

- **GIVEN** two requests concurrently create the same normalized sibling name
- **WHEN** both commit
- **THEN** at most one section is persisted
- **AND** the other request receives a controlled domain error

### Requirement: Same section name may exist under different parent

The system SHALL allow the same normalized section name in different parent contexts within the same property.

#### Scenario: Different towers may each have Piso 1

- **GIVEN** P has roots `Torre A` and `Torre B`
- **WHEN** each root receives a child named `Piso 1`
- **THEN** both sections are valid
- **AND** their paths distinguish them

### Requirement: Property section has controlled section type

The system SHALL require `section_type` to belong to the canonical section-type catalog.

#### Scenario: Canonical type is accepted

- **WHEN** a section uses `building`, `tower`, `floor`, `block`, `stage`, `sector`, `parking_area`, `storage_area`, or `other`
- **THEN** the type may be persisted

#### Scenario: Unknown type is rejected

- **WHEN** a section uses a type outside the configured catalog
- **THEN** creation or update is rejected

### Requirement: Only selected section types may contain units

The system SHALL define `block`, `tower`, and `floor` as the only section types eligible to contain units.

#### Scenario: Eligible section type may contain units

- **WHEN** a section has `section_type` `block`, `tower`, or `floor`
- **THEN** it is eligible for future unit association, subject to property, status, and authorization rules

#### Scenario: Non-eligible section type cannot contain units

- **WHEN** a section has `section_type` `building`, `stage`, `sector`, `parking_area`, `storage_area`, or `other`
- **THEN** it is not eligible for direct unit association

#### Scenario: Unit change consumes eligibility contract

- **WHEN** a future unit flow assigns a unit to a section
- **THEN** it must verify that the section type is `block`, `tower`, or `floor`

### Requirement: Property section has controlled status

The system SHALL restrict status to `active`, `inactive`, or `archived`, with `active` as the ordinary creation default.

#### Scenario: New section defaults to active

- **GIVEN** its property and parent are effectively active
- **WHEN** a valid section is created
- **THEN** its status is `active`

#### Scenario: Invalid status is rejected

- **WHEN** an unknown status is submitted
- **THEN** the operation is rejected

#### Scenario: Inactive ancestor makes descendant non-operational

- **GIVEN** child C has `status = active`
- **AND** an ancestor has `status = inactive`
- **WHEN** C's effective status is evaluated
- **THEN** C is not effectively active

#### Scenario: Archived property prevents section mutation

- **GIVEN** P is archived
- **WHEN** an actor attempts ordinary create, update, move, or archive mutation below P
- **THEN** the operation is denied according to the property lifecycle contract

### Requirement: Sibling position controls stable ordering

The system SHALL use `position` values to order siblings and SHALL provide a deterministic secondary order. When position is not provided, the system MAY assign a controlled default.

#### Scenario: Siblings are ordered by position and name

- **GIVEN** siblings have different or equal positions
- **WHEN** they are serialized in the hierarchy
- **THEN** lower position appears first
- **AND** ties are ordered by normalized name and stable identifier

### Requirement: Property section can be moved safely within same property

The system SHALL move a section within the same property through `PropertySections::Move` while preserving valid child subsections when applicable.

#### Scenario: Root moves under another root as subsection

- **GIVEN** roots A and B belong to active property P
- **WHEN** A is moved under B
- **THEN** A becomes a subsection of B
- **AND** organization and property do not change
- **AND** no third level is created

#### Scenario: Subsection moves to root

- **GIVEN** subsection C belongs to P
- **WHEN** C is moved to the root context
- **THEN** `parent_id` becomes null
- **AND** sibling uniqueness and position are revalidated

#### Scenario: Subsection cannot move under another subsection

- **GIVEN** subsection C belongs to P
- **AND** subsection S also belongs to P
- **WHEN** C is moved under S
- **THEN** the move is rejected
- **AND** the hierarchy remains limited to two levels

#### Scenario: Move causing sibling duplicate is rejected

- **GIVEN** target parent already has `Piso 1`
- **WHEN** another `Piso 1` is moved under that parent
- **THEN** the move is rejected
- **AND** the original hierarchy remains unchanged

### Requirement: Property section cannot be moved across property incorrectly

The system MUST keep a section and its subtree in their original property and organization during move.

#### Scenario: Cross-property move is rejected

- **GIVEN** section S belongs to P
- **WHEN** a request attempts to move S under a parent in Q
- **THEN** the operation is rejected
- **AND** S remains in P

#### Scenario: Client cannot change property during update

- **GIVEN** S belongs to P
- **WHEN** update includes `residential_property_id = Q`
- **THEN** the untrusted value is ignored or rejected
- **AND** S remains in P

### Requirement: Property section can be archived instead of physically deleted

The system SHALL archive a section non-destructively and SHALL preserve subsections, units, visits, and history.

> Exception (setup wizard only): while a property is in `draft`, a section **without** children or units may be removed by soft delete through `PropertySections::Destroy` — see "Draft-phase section removal via soft delete". That path is scoped to draft construction and does not change the rule that, in the ordinary admin flow, archive is the supported operation and deleting a section with dependents is denied.

#### Scenario: Section with children is archived

- **GIVEN** S has child sections
- **WHEN** an authorized actor archives S
- **THEN** S becomes `archived`
- **AND** its children remain persisted
- **AND** its subsections become effectively non-operational

#### Scenario: Section with units is archived

- **GIVEN** S has units
- **WHEN** an authorized actor archives S
- **THEN** S becomes `archived`
- **AND** its units are not hard-deleted

#### Scenario: Hard delete with dependencies is denied

- **GIVEN** S has children, units, visits, or other dependencies
- **WHEN** physical or soft deletion is attempted through the normal admin flow
- **THEN** deletion is denied
- **AND** archive remains the supported lifecycle operation

### Requirement: TreeBuilder returns property-scoped hierarchy

The system SHALL provide `PropertySections::TreeBuilder` that returns an ordered two-level hierarchy for one authorized property without leaking another tenant or property.

#### Scenario: Builder returns roots and subsections

- **GIVEN** P has multiple roots and subsections
- **WHEN** the tree is built for P
- **THEN** every in-scope section appears once under its parent
- **AND** no node is returned below the second level
- **AND** siblings follow deterministic order

#### Scenario: Builder returns UI metadata

- **WHEN** a section node is serialized
- **THEN** it includes id, name, type, position, persisted/effective status, parent, depth, path, children, and backend-computed permissions/actions
- **AND** `add_child` is false for subsections

#### Scenario: Builder excludes another property

- **GIVEN** sections exist in P and Q
- **WHEN** the tree is built for P
- **THEN** no section from Q is returned

#### Scenario: Builder excludes another organization

- **GIVEN** a similarly identified property exists in another organization
- **WHEN** the tree is built in the current tenant
- **THEN** no foreign-organization node is returned

#### Scenario: Builder handles invalid stored graph defensively

- **GIVEN** legacy or corrupted data contains an orphan or cycle
- **WHEN** the tree is built
- **THEN** traversal terminates safely
- **AND** the invalid node is reported or isolated rather than leaking or looping

### Requirement: Tenant admin can manage sections in own organization

The system SHALL allow a tenant administrator to view, create, update, move, change allowed status, and archive sections only within properties of the administrator's organization.

#### Scenario: Tenant admin manages section in own tenant

- **GIVEN** A is tenant admin of O
- **AND** S belongs to active property P in O
- **WHEN** A performs an allowed section operation
- **THEN** authorization succeeds through `Authorization::Resolver` and Pundit

#### Scenario: Tenant admin cannot manage another tenant

- **GIVEN** S belongs to organization Q
- **AND** A is tenant admin of O
- **WHEN** A attempts to access S
- **THEN** authorization is denied

### Requirement: Property admin access is scoped to assigned properties

The system SHALL allow a property administrator to manage sections only where an active, currently valid `StaffAssignment` grants `manage_sections`.

#### Scenario: Assigned property admin manages section

- **GIVEN** A has an active property-admin assignment for P
- **WHEN** A manages a section in P
- **THEN** authorization succeeds

#### Scenario: Inactive assignment grants no access

- **GIVEN** A's assignment for P is inactive, future-dated, or expired
- **WHEN** A attempts to manage a section in P
- **THEN** authorization is denied

#### Scenario: Property admin role is not global

- **GIVEN** A is property admin for P only
- **WHEN** A attempts to manage a section in Q
- **THEN** authorization is denied
- **AND** Q is excluded from policy scope

### Requirement: Cross-organization and cross-property access are denied

The system MUST deny viewing or mutating sections outside the actor's organization and accessible property scope.

#### Scenario: Cross-organization section is hidden

- **WHEN** `PropertySectionPolicy::Scope` resolves
- **THEN** sections from other organizations are excluded

#### Scenario: Cross-property parent is not exposed as option

- **GIVEN** actor A manages P but not Q
- **WHEN** parent options are built for a section in P
- **THEN** no section from Q appears

#### Scenario: User without permission is denied

- **GIVEN** A lacks `manage_sections` for P
- **WHEN** A attempts view, create, update, move, or archive
- **THEN** authorization is denied
- **AND** no mutation occurs

### Requirement: Section mutations use domain services

The system SHALL execute section creation, update, movement, and archive through domain services rather than controller-only logic.

#### Scenario: Create uses service

- **WHEN** an authorized create request is processed
- **THEN** the controller invokes `PropertySections::Create`
- **AND** the service validates property, parent, name, position and authorization

#### Scenario: Update uses service

- **WHEN** an authorized descriptive update is processed
- **THEN** the controller invokes `PropertySections::Update`
- **AND** parent/property lifecycle is not changed implicitly

#### Scenario: Move uses service

- **WHEN** an authorized parent or position change is requested
- **THEN** the controller invokes `PropertySections::Move`
- **AND** hierarchy and concurrency rules are revalidated

#### Scenario: Archive uses service

- **WHEN** an authorized archive request is processed
- **THEN** the controller invokes `PropertySections::Archive`
- **AND** does not use cascading destroy as archive behavior

#### Scenario: Frontend cannot bypass domain rules

- **GIVEN** frontend validation or disabled controls are bypassed
- **WHEN** an invalid mutation reaches the backend
- **THEN** service/model/policy validation rejects it

### Requirement: Draft-phase section removal via soft delete

During the setup wizard (draft property), the system SHALL allow removal of a section that has no children and no units through `PropertySections::Destroy`. This use case performs a paranoia soft delete (`section.destroy`) rather than `Archive`, so the section disappears from the default scope and the live preview reflects the removal immediately.

`PropertySections::Destroy` is only valid while the property is in `draft` status. It MUST be authorized through the setup/manage-sections capability (`authorize_setup_property!`) and scoped to the current property and organization. The existing `dependent: :restrict_with_error` on `children` and `units` governs what can be deleted: a section with dependents fails cleanly and the error is surfaced to the user.

`Archive` remains the supported lifecycle operation for the ordinary non-wizard admin flow. `Destroy` is additive and applies only during draft construction.

#### Scenario: Empty leaf section is soft-deleted during setup

- **GIVEN** a draft property with a section that has no children and no units
- **WHEN** an authorized user confirms deletion in the wizard
- **THEN** `PropertySections::Destroy` soft-deletes the section via paranoia
- **AND** the section disappears from the live structure preview
- **AND** the audit trail is preserved via `deleted_at`

#### Scenario: Destroy is blocked when dependents exist

- **GIVEN** a section that has child sections or units
- **WHEN** `PropertySections::Destroy` is called
- **THEN** the operation is rejected due to `dependent: :restrict_with_error`
- **AND** a clear error is returned and no record is deleted

#### Scenario: Destroy requires draft property status

- **GIVEN** a property that is not in `draft` status
- **WHEN** `PropertySections::Destroy` is invoked on one of its sections
- **THEN** the operation is rejected with a property lifecycle error
- **AND** the section remains intact

#### Scenario: Soft-deleted section does not conflict on re-create

- **GIVEN** a section was soft-deleted via `Destroy`
- **WHEN** a new section with the same name and parent is created
- **THEN** creation succeeds because the unique index is scoped `WHERE deleted_at IS NULL`
- **AND** no uniqueness error is raised for the removed section

### Requirement: Property section code is always system-derived

The system SHALL always derive `PropertySection#code` on create. Root sections MUST incorporate the residential property code (derived in-memory if the property is unsaved), the section `section_type` abbreviation, and a slug of the section `name`. Child sections MUST incorporate the parent section code and a slug of the child `name`. Derived codes MUST satisfy the alphanumeric-hyphen format and uniqueness within `(organization, residential_property, parent_id, section_type)`. Any client-submitted `code` MUST be stripped and replaced by the derived value.

#### Scenario: Root section code is derived

- **GIVEN** property P has `code: clp` and no root section with code `clp-tor-torre-a`
- **WHEN** a root section is created with `name: "Torre A"` and `section_type: tower`
- **THEN** the persisted `code` is `clp-tor-torre-a`

#### Scenario: Child section code extends parent code

- **GIVEN** parent section S has `code: clp-tor-torre-a`
- **WHEN** a child is created under S with `name: "Piso 1"`
- **THEN** the persisted `code` is `clp-tor-torre-a-piso-1`

#### Scenario: Section code collision in same context receives suffix

- **GIVEN** a child section already exists with `code: clp-tor-torre-a-piso-1` under the same parent and `section_type` due to legacy data or a console correction
- **WHEN** another child derives the same base code without violating section name uniqueness
- **THEN** the new section receives `code: clp-tor-torre-a-piso-1-2`

#### Scenario: Client-submitted code is ignored

- **WHEN** a section is created via a user-facing path with `code: "CUSTOM-SEC"` in the request
- **THEN** the persisted `code` is the server-derived value, not `CUSTOM-SEC`

#### Scenario: Batch create derives code per section

- **WHEN** multiple sections are created in one batch
- **THEN** each persisted section receives its own derived code based on its own `name` and placement context

#### Scenario: Section rename or move does not change code

- **GIVEN** section S has `code: clp-tor-torre-a-piso-1`
- **WHEN** S is renamed or moved through a supported update path
- **THEN** S keeps `code: clp-tor-torre-a-piso-1`
