# mobile-residential-property-detail

## Purpose

TBD

## Requirements

### Requirement: Residential property detail endpoint for mobile clients
The system SHALL provide `GET /api/v1/mobile/organization/:organization_id/residential_property/:id`, which returns the requested residential property's `id`, `name`, `property_type`, and `address` (an object with `address_line`, `city`, `region`), along with `units`: an array of units within that property the authenticated user is linked to. `units` SHALL contain one entry per unit where the user's `Person` record in that organization has an active `UnitOwnership` and/or an active `UnitOccupancy` on a unit belonging to that residential property, AND the unit's `status` is `available` or `occupied` — a unit linked both ways SHALL appear exactly once; a unit whose `status` is `inactive`, `maintenance`, or `archived` SHALL NOT appear regardless of ownership/occupancy. Each unit entry SHALL contain `id`, `code`, `display_name`, `unit_type`, `is_owner` (boolean), and `occupancy_type` (the raw active occupancy type, or `null` when the user has no active occupancy on that unit). The requested residential property SHALL only be returned when its own `status` is `active`. Every failure mode — the organization not existing, the user having no active/invited membership in it, the residential property not existing (or not belonging to that organization), the property's `status` not being `active`, or the filtered `units` array being empty — SHALL respond identically with `404 Not Found`, with no distinguishing signal between causes.

#### Scenario: User fetches a residential property they have units in
- **WHEN** an authenticated user with an active `Person` membership in organization `X` and at least one active `UnitOwnership` or `UnitOccupancy` on an `available`/`occupied` unit within active residential property `P` (belonging to `X`) calls `GET /api/v1/mobile/organization/X/residential_property/P`
- **THEN** the system responds `200 OK` with `data.id`, `data.name`, `data.property_type`, `data.address` matching property `P`, and `data.units` as a non-empty array

#### Scenario: Unit held via both active ownership and active occupancy
- **WHEN** the user's `Person` has an active `UnitOwnership` and an active `UnitOccupancy` on the same `available`/`occupied` unit within the requested residential property
- **THEN** that unit appears exactly once in `data.units`, with `is_owner: true` and `occupancy_type` set to the active occupancy's type

#### Scenario: Unit held only via ownership
- **WHEN** the user's `Person` has an active `UnitOwnership` on an `available`/`occupied` unit within the requested residential property but no active `UnitOccupancy` on it
- **THEN** that unit appears in `data.units` with `is_owner: true` and `occupancy_type: null`

#### Scenario: Unit held only via occupancy
- **WHEN** the user's `Person` has an active `UnitOccupancy` on an `available`/`occupied` unit within the requested residential property but no active `UnitOwnership` on it
- **THEN** that unit appears in `data.units` with `is_owner: false` and `occupancy_type` set to the active occupancy's type

#### Scenario: Inactive ownership or occupancy is excluded
- **WHEN** the user's `Person` has a `UnitOwnership` or `UnitOccupancy` on a unit within the requested residential property whose `status` is not active
- **THEN** that unit does not appear in `data.units` on account of that relationship alone

#### Scenario: Unit with ineligible status is excluded even with active ownership or occupancy
- **WHEN** the user's `Person` has an active `UnitOwnership` and/or active `UnitOccupancy` on a unit within the requested residential property whose `status` is `inactive`, `maintenance`, or `archived`
- **THEN** that unit does not appear in `data.units`

#### Scenario: Units from other residential properties are excluded
- **WHEN** the user's `Person` has an active `UnitOwnership` or `UnitOccupancy` on an `available`/`occupied` unit belonging to a different residential property within the same organization
- **THEN** that unit does not appear in `data.units` for the requested residential property

#### Scenario: User has no organization membership
- **WHEN** an authenticated user has no `Person` record with an active or invited `organization_membership` in the requested organization `:organization_id`
- **THEN** the system responds `404 Not Found`

#### Scenario: Organization id does not exist
- **WHEN** an authenticated user calls the endpoint for an `:organization_id` that does not correspond to any organization
- **THEN** the system responds `404 Not Found`, identically to the no-membership case

#### Scenario: Residential property id does not exist or belongs to a different organization
- **WHEN** an authenticated member of organization `X` calls the endpoint with an `:id` that does not correspond to any residential property, or that corresponds to a residential property belonging to a different organization
- **THEN** the system responds `404 Not Found`, identically to the no-membership case

#### Scenario: Residential property is not active
- **WHEN** an authenticated member of organization `X` calls the endpoint for a residential property within `X` whose `status` is `draft`, `created`, `configured`, `inactive`, or `archived`
- **THEN** the system responds `404 Not Found`, regardless of any units the user has within that property

#### Scenario: Member has no eligible units in an otherwise-accessible property
- **WHEN** an authenticated user has an active `Person` membership in organization `X` and the requested residential property `P` is active and belongs to `X`, but the user has no active `UnitOwnership` or `UnitOccupancy` on any `available`/`occupied` unit within `P`
- **THEN** the system responds `404 Not Found`, identically to the no-membership case, rather than `200 OK` with an empty `units` array

#### Scenario: Unauthenticated request is rejected
- **WHEN** a request to `GET /api/v1/mobile/organization/:organization_id/residential_property/:id` is made with no `Authorization` header, or an invalid/expired JWT
- **THEN** the system responds `401 Unauthorized`
