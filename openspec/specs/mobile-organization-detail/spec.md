## Purpose

TBD

## Requirements

### Requirement: Organization detail endpoint for mobile clients
The system SHALL provide `GET /api/v1/mobile/organization/:id`, which returns the requested organization's `name`, `cover`, and `logo`, along with `residential_properties`: an array of the residential properties in that organization where the authenticated user is linked to at least one unit. `residential_properties` SHALL contain one entry per `ResidentialProperty` that has at least one unit the user's `Person` record in that organization has an active `UnitOwnership` and/or an active `UnitOccupancy` on; properties with none of the user's units SHALL be omitted. Each residential property entry SHALL contain `id`, `name`, `property_type`, `address` (an object with `address_line`, `city`, `region`), and `units`. `units` SHALL contain one entry per unit within that property where the user's `Person` has an active `UnitOwnership` and/or an active `UnitOccupancy` — a unit linked both ways SHALL appear exactly once. Each unit entry SHALL contain `id`, `code`, `display_name`, `unit_type`, `is_owner` (boolean), and `occupancy_type` (the raw active occupancy type, or `null` when the user has no active occupancy on that unit).

#### Scenario: User fetches an organization they belong to
- **WHEN** an authenticated user with an active `Person` membership in organization `X` calls `GET /api/v1/mobile/organization/X`
- **THEN** the system responds `200 OK` with `data.name`, `data.cover`, `data.logo` matching organization `X`, and `data.residential_properties` as an array

#### Scenario: Unit held via both active ownership and active occupancy
- **WHEN** the user's `Person` has an active `UnitOwnership` and an active `UnitOccupancy` on the same unit within the requested organization
- **THEN** that unit appears exactly once within its residential property's `units`, with `is_owner: true` and `occupancy_type` set to the active occupancy's type

#### Scenario: Unit held only via ownership
- **WHEN** the user's `Person` has an active `UnitOwnership` on a unit but no active `UnitOccupancy` on it
- **THEN** that unit appears within its residential property's `units` with `is_owner: true` and `occupancy_type: null`

#### Scenario: Unit held only via occupancy
- **WHEN** the user's `Person` has an active `UnitOccupancy` on a unit but no active `UnitOwnership` on it
- **THEN** that unit appears within its residential property's `units` with `is_owner: false` and `occupancy_type` set to the active occupancy's type

#### Scenario: Inactive ownership or occupancy is excluded
- **WHEN** the user's `Person` has a `UnitOwnership` or `UnitOccupancy` on a unit whose `status` is not active
- **THEN** that unit does not appear in any residential property's `units` on account of that relationship alone

#### Scenario: User has units across multiple residential properties
- **WHEN** the user's `Person` has active `UnitOwnership` and/or `UnitOccupancy` records on units belonging to two different residential properties within the requested organization
- **THEN** `data.residential_properties` contains one entry per property, each with `id`, `name`, `property_type`, `address`, and only that property's units from among the user's linked units

#### Scenario: Residential property with none of the user's units is omitted
- **WHEN** a residential property in the requested organization exists but the user's `Person` has no active `UnitOwnership` or `UnitOccupancy` on any unit within it
- **THEN** that residential property does not appear in `data.residential_properties`

#### Scenario: User has no organization membership
- **WHEN** an authenticated user has no `Person` record with an active or invited `organization_membership` in the requested organization `:id`
- **THEN** the system responds `404 Not Found`

#### Scenario: Organization id does not exist
- **WHEN** an authenticated user calls `GET /api/v1/mobile/organization/:id` for an `:id` that does not correspond to any organization
- **THEN** the system responds `404 Not Found`, identically to the no-membership case

#### Scenario: User has no units in an organization they belong to
- **WHEN** an authenticated user has an active `Person` membership in organization `X` but no active `UnitOwnership` or `UnitOccupancy` there
- **THEN** the system responds `200 OK` with `data.residential_properties` as an empty array

#### Scenario: Unauthenticated request is rejected
- **WHEN** a request to `GET /api/v1/mobile/organization/:id` is made with no `Authorization` header, or an invalid/expired JWT
- **THEN** the system responds `401 Unauthorized`
