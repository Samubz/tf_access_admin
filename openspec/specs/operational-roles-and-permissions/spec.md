# Operational Roles and Permissions

## Purpose

Define the operational authorization model for the residential property platform: organizational and property-scoped roles, capability-based permissions, Pundit policy integration, tenant isolation, and preparation for visit management — while keeping `Person` as the canonical identity entity separate from operational authority.

## Requirements

### Requirement: Operational roles are separate from Person identity

The system SHALL treat `Person` as the canonical identity store per organization. Operational authorization MUST be resolved from the authenticated `User` through `OrganizationMembership`, organizational Rolify roles, `StaffAssignment`, and domain relationships (`UnitOwnership`, `UnitOccupancy`). The system MUST NOT store operational role names as primary attributes on `Person`.

#### Scenario: Person identity without system access

- **WHEN** a `Person` exists without a linked `User`
- **THEN** the person may appear in ownership, occupancy, or staff assignment records
- **AND** no operational capabilities are granted for system login until a `User` is linked

#### Scenario: User resolves person in current organization

- **WHEN** an authenticated `User` operates within organization O
- **THEN** authorization resolution uses `user.person_for(O)` as the organizational identity anchor
- **AND** does not use `Person` records from other organizations

### Requirement: Organization-level Super Admin role

The system SHALL grant full organizational capabilities to users with `super_admin` (platform) or `tenant_admin` scoped to the current organization.

#### Scenario: Tenant admin manages all organization resources

- **WHEN** a user has active `tenant_admin` role for the current organization
- **THEN** the resolver grants all organization and property capabilities within that organization
- **AND** policy scopes include all tenant-scoped records for that organization

#### Scenario: Super admin cross-tenant access

- **WHEN** a user has global `super_admin` role
- **THEN** the resolver grants full capabilities in any organization context
- **AND** tenant isolation still applies to data queries scoped by `ActsAsTenant.current_tenant`

#### Scenario: Tenant admin cannot access another organization

- **WHEN** a tenant admin of organization A attempts to access a record belonging to organization B
- **THEN** authorization denies access
- **AND** policy scopes return no records from organization B

### Requirement: Property Administrator role via StaffAssignment

The system SHALL grant property-scoped administrative capabilities to users whose linked `Person` has an active `StaffAssignment` mapped to `property_admin`.

#### Scenario: Property admin manages assigned property

- **WHEN** a user has an active `StaffAssignment` mapped to `property_admin` for residential property P
- **THEN** the resolver grants `manage_units`, `manage_people`, `manage_ownerships`, `manage_occupancies`, `manage_staff_assignments`, `manage_visits`, and related view capabilities scoped to P
- **AND** the user may mutate resources belonging to P
- **AND** those capabilities do not apply to any other property

#### Scenario: Property admin cannot manage unassigned property

- **WHEN** a user is property administrator only for property P
- **AND** attempts to mutate a unit belonging to property Q in the same organization
- **THEN** authorization denies the action
- **AND** policy scopes exclude resources from property Q

#### Scenario: Property admin role is not global

- **WHEN** a user has no active `StaffAssignment` mapped to `property_admin` for property P
- **THEN** the resolver does not grant `manage_property`, `manage_units`, `manage_ownerships`, or `manage_occupancies` for property P

#### Scenario: Property admin manages staff on assigned property

- **WHEN** a property administrator assigns or revokes concierge staff on property P
- **THEN** the operation is authorized
- **AND** only affects `StaffAssignment` rows scoped to P

### Requirement: Concierge role via StaffAssignment

The system SHALL grant visit access-control capabilities only to users whose linked `Person` has an active `StaffAssignment` mapped to `concierge` for a residential property. Concierge capabilities MUST be scoped to that property and MUST NOT be granted globally across the organization.

#### Scenario: Concierge registers visit entry

- **WHEN** a concierge with active assignment on property P registers entry for an authorized visit at P
- **THEN** the action is authorized with `register_visit_entry`

#### Scenario: Concierge registers visit exit

- **WHEN** a concierge with active assignment on property P registers exit for a visit at P
- **THEN** the action is authorized with `register_visit_exit`

#### Scenario: Concierge views authorized visits

- **WHEN** a concierge queries visits for property P
- **THEN** the system returns only visits for P
- **AND** authorization requires `view_authorized_visits`

#### Scenario: Concierge cannot access unassigned property

- **WHEN** a concierge is assigned only to property P
- **AND** attempts to view visits or access-control data for property Q
- **THEN** authorization denies the action
- **AND** policy scopes exclude property Q

#### Scenario: Concierge cannot modify ownerships

- **WHEN** a concierge attempts to create, update, or destroy a `UnitOwnership`
- **THEN** authorization denies the action

#### Scenario: Concierge cannot manage users

- **WHEN** a concierge attempts to create, update, or destroy organization users
- **THEN** authorization denies the action

#### Scenario: Concierge cannot access full person profile by default

- **WHEN** a concierge attempts to access the full unified profile of a person related to their assigned property
- **THEN** authorization denies the action unless an explicit `view_people` capability is granted
- **AND** concierge workflows must use minimal access-control serializers instead

### Requirement: Resident and Owner capabilities from domain relationships

The system SHALL derive resident and owner visit-related capabilities from active `UnitOccupancy` and `UnitOwnership` records on the user's linked `Person`, scoped to the units and properties involved.

#### Scenario: Resident creates visit for own unit

- **WHEN** a user has an active `UnitOccupancy` on unit U
- **AND** attempts to create a visit for U
- **THEN** authorization grants `create_visits` for U

#### Scenario: Owner creates visit for owned unit

- **WHEN** a user has an active `UnitOwnership` on unit U
- **AND** attempts to create a visit for U
- **THEN** authorization grants `create_visits` for U

#### Scenario: Occupant with authorization capability may authorize visits

- **WHEN** a user's active occupancy on unit U grants visit authorization according to occupancy rules
- **AND** the user attempts to authorize a pending visit for U
- **THEN** authorization grants `authorize_visits` for that visit

#### Scenario: Resident views own visits only

- **WHEN** a resident queries visits
- **THEN** policy scope returns only visits linked to units where the user has active ownership or occupancy
- **AND** does not return visits for other units

#### Scenario: Resident cannot manage other people's records

- **WHEN** a resident attempts to update another person's `Person` record
- **THEN** authorization denies the action

#### Scenario: Resident cannot access admin reports

- **WHEN** a resident attempts to access organization-wide admin reports
- **THEN** authorization denies the action

### Requirement: Internal staff with limited permissions

The system SHALL support internal staff roles through `StaffAssignment` with a fixed capability map per mapped staff role. Raw staff types such as `cleaning`, `security`, `maintenance`, and `other` MUST be normalized to operational roles such as `cleaning_staff`, `concierge`, or `internal_staff`.

#### Scenario: Internal staff without visit permissions

- **WHEN** a user has active `cleaning` staff assignment on property P
- **AND** no explicit visit capabilities are configured for that staff type
- **THEN** the user cannot register visit entry or exit
- **AND** may only exercise capabilities mapped to `cleaning`

#### Scenario: Internal staff scoped to assigned property

- **WHEN** internal staff is assigned to property P only
- **THEN** all granted capabilities apply only within P
- **AND** policy scopes exclude other properties

### Requirement: Capability catalog is the authorization contract

The system SHALL define a stable catalog of atomic capabilities in `Authorization::Capabilities`. Pundit policies MUST check capabilities through `Authorization::Resolver`, not hard-coded role name strings in policy methods.

#### Scenario: Policy delegates to resolver

- **WHEN** `UnitOwnershipPolicy#create?` is evaluated
- **THEN** the policy checks `allowed?(:manage_ownerships)` on a resolver scoped to the ownership's residential property
- **AND** does not check only `admin?`

#### Scenario: Unknown capability denies by default

- **WHEN** a policy checks a capability not granted by any source
- **THEN** authorization returns false

### Requirement: Authorization resolver combines all sources

The system SHALL provide `Authorization::Resolver` that evaluates, in order: super admin, tenant admin, active staff assignments, active ownerships and occupancies — producing the union of granted capabilities for the given organization and optional residential property context.

#### Scenario: Multiple capability sources combine

- **WHEN** a user is tenant admin and also has concierge assignment on property P
- **THEN** the resolver grants full org capabilities plus concierge capabilities on P without conflict

#### Scenario: Inactive staff assignment grants no capabilities

- **WHEN** a `StaffAssignment` has status other than active or is outside its validity dates
- **THEN** the resolver does not grant capabilities from that assignment

#### Scenario: Resolver is memoized per request

- **WHEN** multiple policies are evaluated in the same request
- **THEN** capability resolution for the same user and organization is not recomputed from scratch for each policy call

#### Scenario: Resolver memoization does not leak property context

- **WHEN** authorization is evaluated for property P and later for property Q in the same request
- **THEN** cached capability checks remain scoped to their own property context
- **AND** capabilities granted for P are not reused for Q

### Requirement: Strict organization isolation in authorization

The system SHALL enforce tenant isolation in every policy and policy scope. No operational role MAY grant access to records outside the current organization.

#### Scenario: Cross-organization record access denied

- **WHEN** a user with any operational role in organization A requests a record with `organization_id` B
- **THEN** authorization denies access
- **AND** `same_organization?` checks fail

#### Scenario: Policy scope never leaks cross-tenant

- **WHEN** any policy scope resolves for a tenant-scoped model
- **THEN** results are filtered by `organization_id` equal to `ActsAsTenant.current_tenant.id`

### Requirement: Property-scoped policy scopes

The system SHALL provide `Authorization::PropertyScope` (or equivalent) to compute accessible `residential_property_id` values per user. Resource policy scopes for `ResidentialProperty`, `Unit`, `Person`, `UnitOwnership`, `UnitOccupancy`, and future `Visit` MUST respect accessible properties unless the user has organization-wide access.

#### Scenario: Property admin scope limited to assignments

- **WHEN** a property administrator is assigned to properties P1 and P2
- **THEN** `ResidentialPropertyPolicy::Scope` returns only P1 and P2
- **AND** `UnitPolicy::Scope` returns only units under P1 and P2

#### Scenario: Tenant admin scope is organization-wide

- **WHEN** a tenant admin resolves property scope
- **THEN** all residential properties in the organization are accessible

#### Scenario: Concierge scope matches assignment

- **WHEN** a concierge is assigned to property P
- **THEN** visit policy scope includes only visits at P

### Requirement: Pundit policies implement capability checks

The system SHALL update existing policies (`PersonPolicy`, `UnitPolicy`, `UnitOwnershipPolicy`, `UnitOccupancyPolicy`, `ResidentialPropertyPolicy`, `UserPolicy`, `PropertySectionPolicy`, `BulkImportPolicy`) to use capability-based authorization and property-aware scopes.

#### Scenario: PersonPolicy view vs manage

- **WHEN** a user has `view_people` for property P
- **THEN** the user may `show?` persons with ownership, occupancy, or staff relationship to P
- **WHEN** a user has `manage_people`
- **THEN** the user may create, update, and destroy persons within their accessible scope

#### Scenario: UserPolicy restricted to organization admins

- **WHEN** a user without `manage_users` attempts user management actions
- **THEN** authorization denies index, create, update, and destroy on users

#### Scenario: Client role without operational assignment has no admin access

- **WHEN** a user has only `client` organizational role and no staff assignment or ownership/occupancy
- **THEN** admin policy scopes return empty sets
- **AND** admin mutations are denied

### Requirement: Visit authorization contract is prepared for future visit module

The system SHALL define the authorization contract for the future `VisitPolicy`, including expected methods and capabilities, without requiring visit CRUD implementation in this change.

#### Scenario: Future visit creation uses resident or owner capabilities

- **WHEN** a user has `create_visits` for a unit
- **THEN** the future `VisitPolicy#create?` SHALL authorize creating visits for that unit

#### Scenario: Future visit authorization uses unit-scoped authorization capability

- **WHEN** a user has `authorize_visits` for a unit
- **THEN** the future `VisitPolicy#authorize?` SHALL authorize approving visits for that unit

#### Scenario: Future concierge check-in uses property-scoped capability

- **WHEN** a concierge has `register_visit_entry` for property P
- **THEN** the future `VisitPolicy#check_in?` SHALL authorize check-in only for visits belonging to property P

#### Scenario: Future concierge check-out uses property-scoped capability

- **WHEN** a concierge has `register_visit_exit` for property P
- **THEN** the future `VisitPolicy#check_out?` SHALL authorize check-out only for visits belonging to property P

#### Scenario: Future concierge minimal access uses restricted serializers

- **WHEN** a concierge views visit details for access control
- **THEN** only fields allowed by `view_minimal_access_control_data` are exposed in serializers intended for concierge context
- **AND** full person administrative fields remain hidden

### Requirement: Staff assignments derive contextual roles

The system SHALL extend `People::ContextualRoles` to derive `concierge`, `property_admin`, `cleaning_staff`, and `internal_staff` badges from active `StaffAssignment` records for the person. Staff contextual roles MUST be scoped to the current organization and derived from property-level assignments, not from global user roles.

#### Scenario: Internal staff assignment shows badge

- **WHEN** a person has an active `StaffAssignment` mapped to `internal_staff`
- **THEN** `People::ContextualRoles` includes `internal_staff`
- **AND** the unified person profile displays the Personal interno badge

#### Scenario: Active concierge assignment shows badge

- **WHEN** a person has an active `StaffAssignment` with `staff_type` `concierge`
- **THEN** `People::ContextualRoles` includes `concierge`
- **AND** the unified person profile displays the Conserje badge

#### Scenario: Cleaning staff assignment shows badge

- **WHEN** a person has an active `StaffAssignment` mapped to `cleaning_staff`
- **THEN** `People::ContextualRoles` includes `cleaning_staff`
- **AND** the unified person profile displays the Personal de aseo badge

#### Scenario: Property admin assignment shows badge

- **WHEN** a person has an active `StaffAssignment` mapped to `property_admin`
- **THEN** derived contextual roles include `property_admin`
- **AND** the unified person profile displays the Administrador de propiedad badge

#### Scenario: Ended assignment removes staff badge

- **WHEN** a staff assignment becomes inactive or past `ends_at`
- **THEN** the corresponding staff contextual role is no longer derived

#### Scenario: Staff assignment from another organization is ignored

- **WHEN** a person has a `StaffAssignment` associated with a residential property from another organization
- **THEN** derived contextual roles for the current organization do not include that staff role

### Requirement: Person profile permissions respect operational capabilities

The system SHALL expose person profile `permissions` props based on the current user's capabilities relative to the profile person's property contexts.

#### Scenario: Property admin can view and edit person in scope

- **WHEN** a property administrator has `manage_people` for a property where the profile person has an active relationship
- **THEN** profile permissions include view and edit actions

#### Scenario: Concierge cannot access full unified profile by default

- **WHEN** a concierge has no `view_people` capability for the profile person's property context
- **THEN** the full unified profile is denied
- **AND** concierge workflows must use minimal access-control serializers instead

#### Scenario: Property admin denied outside assigned property scope

- **WHEN** a property administrator requests the profile of a person related only to another property
- **THEN** the system denies access

### Requirement: Future user management UI contract

The system SHALL define a domain contract for future user and permission management screens without implementing those screens in this change.

#### Scenario: Operational user summary shape

- **WHEN** a future admin users index is implemented
- **THEN** each row can be populated from: user id, email, name, linked person id, organization role, managed properties list, staff assignments summary, account status, and effective capability keys

### Requirement: Operational role assignment services manage StaffAssignment

The system SHALL provide service objects to assign and revoke property-scoped operational roles without requiring a UI in this change.

#### Scenario: Assign property administrator

- **WHEN** `OperationalRoles::AssignPropertyAdmin` is called with an actor, user, organization, and residential property
- **THEN** it creates or updates an active `StaffAssignment` mapped to `property_admin`
- **AND** the assignment is scoped only to that property

#### Scenario: Assign concierge

- **WHEN** `OperationalRoles::AssignConcierge` is called with an actor, user, organization, and residential property
- **THEN** it creates or updates an active `StaffAssignment` mapped to `concierge`
- **AND** the assignment is scoped only to that property

#### Scenario: Assign internal staff

- **WHEN** `OperationalRoles::AssignInternalStaff` is called with an actor, user, organization, residential property, and staff type
- **THEN** it creates or updates an active `StaffAssignment` mapped to the corresponding internal staff role
- **AND** no administrative capability is granted unless explicitly defined by the capability map

#### Scenario: Revoke operational assignment

- **WHEN** `OperationalRoles::RevokeAssignment` is called for an active assignment
- **THEN** the assignment is deactivated or ended
- **AND** capabilities from that assignment are no longer granted

#### Scenario: Assignment requiring system access validates linked user

- **WHEN** an operational assignment requires access to the system
- **AND** the target person has no linked `User`
- **THEN** the service rejects the assignment with a validation error

### Requirement: Admin layout exposes effective capabilities

The system SHALL expose the current user's effective capability keys (or a structured permissions object) to Inertia shared props or page props for conditional UI rendering.

#### Scenario: Navigation hidden without capability

- **WHEN** a concierge loads the admin layout
- **THEN** navigation items requiring `manage_people` or `manage_users` are not rendered
- **AND** visit-related navigation items are visible when `view_authorized_visits` is granted

#### Scenario: Capabilities scoped to current organization

- **WHEN** capabilities are serialized for the frontend
- **THEN** they reflect only the current `ActsAsTenant.current_tenant` context

### Requirement: Authorization changes are auditable

The system SHALL audit mutations to `StaffAssignment` and organizational role changes that affect operational access.

#### Scenario: Staff assignment creation audited

- **WHEN** an active staff assignment is created
- **THEN** an audit record captures assigner, person, property, staff_type, and status

#### Scenario: Staff assignment revocation audited

- **WHEN** a staff assignment is deactivated or revoked
- **THEN** an audit record captures the change and timestamp

### Requirement: Tests cover role and scope matrix

The system SHALL include automated tests for `Authorization::Resolver`, `Authorization::PropertyScope`, updated policies, and representative scenarios per MVP role.

#### Scenario: Resolver test per role

- **WHEN** the test suite runs
- **THEN** there are tests asserting granted and denied capabilities for tenant admin, property admin, concierge, resident/owner, and internal staff

#### Scenario: Policy scope isolation test

- **WHEN** a property admin resolves `UnitPolicy::Scope`
- **THEN** tests verify units from unassigned properties are excluded

#### Scenario: Cross-organization denial test

- **WHEN** any role from organization A accesses organization B records in policy specs
- **THEN** tests expect authorization failure
