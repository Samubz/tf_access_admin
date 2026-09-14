# Mobile Private API

## ADDED Requirements

### Requirement: Private API login is available to any confirmed tenant member

The system SHALL authenticate a `User` through `POST /api/v1/auth/login` when the credentials are valid, the account is confirmed and the user is a member of the organization resolved from the request subdomain. The response SHALL include `role` with one of `tenant_admin`, `resident`, `visitor`.

#### Scenario: Resident logs in

- **GIVEN** a confirmed `User` whose `Person` has an active `UnitOccupancy` in organization O and no organizational role
- **WHEN** the user submits valid credentials to O's subdomain
- **THEN** the system returns `200` with a JWT and `role: "resident"`

#### Scenario: Visitor logs in

- **GIVEN** a confirmed `User` with an active `OrganizationMembership` with role `visitor` in O
- **WHEN** the user submits valid credentials to O's subdomain
- **THEN** the system returns `200` with a JWT and `role: "visitor"`

#### Scenario: Non-member is rejected

- **GIVEN** a confirmed `User` with no membership nor unit relationship in O
- **WHEN** the user submits valid credentials to O's subdomain
- **THEN** the system returns `403` and no token

### Requirement: Profile endpoint

The system SHALL expose `GET /api/v1/private/me` returning `{ data: { email, name, dni, phone: { countryCode, number } | null, dateOfBirth: string | null, gender: null, avatarUrl: string | null, role, organizations: [{ id, name, logo: string | null, units_count }] } }` for the authenticated user, and `PATCH /api/v1/private/me` accepting `name`, `phone`, `dateOfBirth` and a multipart `avatar`.

#### Scenario: Profile reflects the current tenant's person

- **GIVEN** an authenticated resident whose `Person` in O has a phone and birthdate
- **WHEN** the user requests `GET /me`
- **THEN** `phone` and `dateOfBirth` come from that `Person`
- **AND** `organizations` lists only organizations where the user has an active membership or unit relationship
- **AND** `gender` is `null`

#### Scenario: Profile update persists name and avatar

- **WHEN** the user sends `PATCH /me` with a new `name` and an image `avatar`
- **THEN** the system stores the name on the `User`, attaches the avatar and returns the updated profile with a non-null `avatarUrl`

### Requirement: Units endpoint

The system SHALL expose `GET /api/v1/private/units` returning `{ data: [{ id, name, organization: { id, name } }] }` with the units where the authenticated user's `Person` in the current organization has an active `UnitOccupancy` or `UnitOwnership`.

#### Scenario: Only related units are listed

- **GIVEN** the user's `Person` has an active occupancy on unit U1 and no relationship with U2 in the same property
- **WHEN** the user requests `GET /units`
- **THEN** the response contains U1 and not U2

#### Scenario: Visitor has no units

- **GIVEN** a user whose only relationship with O is a `visitor` membership
- **WHEN** the user requests `GET /units`
- **THEN** the response is `200` with an empty list

### Requirement: Organization detail endpoints

The system SHALL expose `GET /api/v1/private/organization/:id` returning `{ data: { name, cover, logo, residentialProperties: [{ id, name, propertyType, address: { addressLine, city, region }, units: [{ id, code, displayName, unitType, isOwner, occupancyType }], organizationId }] } }` and `GET /api/v1/private/organization/:id/residential_property/:property_id` returning one property with the same shape, both restricted to properties and units where the user has an active relationship.

#### Scenario: Organization id must match the tenant

- **GIVEN** an authenticated user in O
- **WHEN** the user requests `GET /organization/:id` with the id of another organization
- **THEN** the system returns `404`

#### Scenario: Owner flag reflects ownership

- **GIVEN** the user's `Person` owns unit U and occupies unit V
- **WHEN** the user requests the organization detail
- **THEN** U has `isOwner: true` and V has `isOwner: false` with its `occupancyType`

### Requirement: Unit visits by day

The system SHALL expose `GET /api/v1/private/units/:unit_id/visits?day=YYYY-MM-DD` returning `{ data: [{ id, visitor_name, status, scheduled_at, checked_in_at, checked_out_at }] }` for visits of that unit whose `scheduled_at` falls on that day in the property's time zone, under the same resident guard as visit creation.

#### Scenario: Resident lists a day's visits

- **GIVEN** a resident allowed to create visits for U with two visits on 2026-09-20 and one on 2026-09-21
- **WHEN** the resident requests `GET /units/U/visits?day=2026-09-20`
- **THEN** the response lists exactly the two visits of that day

#### Scenario: Invalid day is rejected

- **WHEN** the resident requests with `day=2026-13-40`
- **THEN** the system returns `422` with a localized error

#### Scenario: Unit from another organization

- **WHEN** the resident requests visits of a unit belonging to another organization
- **THEN** the system returns `404`

### Requirement: Visitor invitations endpoint

The system SHALL expose `GET /api/v1/private/invitations` returning `{ data: [{ id, status, scheduled_at, residential_property_name, unit_identifier, host_name, access_code: null }] }` with the visits where `visitor_person.user_id` equals the authenticated user, scheduled from the start of the current day onwards and not `cancelled`, for users holding the `view_own_visits` capability.

#### Scenario: Visitor sees only own upcoming invitations

- **GIVEN** user V is the visitor of visit A (tomorrow) and visit B (last week), and another user is visitor of visit C (tomorrow)
- **WHEN** V requests `GET /invitations`
- **THEN** the response contains A only

#### Scenario: Response carries no other person's data

- **WHEN** V requests `GET /invitations`
- **THEN** each item includes the host's display name and no document, phone or email of any person
