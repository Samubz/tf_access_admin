# operational-roles-and-permissions

## ADDED Requirements

### Requirement: Organization-level Visitor role

The system SHALL define an organizational role `visitor` whose only capability is `view_own_visits`. A `visitor` MUST NOT receive any capability over units, properties, people or visit management. The `view_own_visits` capability SHALL also be granted to any user who is the `visitor_person` of a visit in the organization.

#### Scenario: Visitor capabilities are minimal

- **GIVEN** a user whose only relationship with O is a `visitor` membership
- **WHEN** the authorization resolver computes effective capabilities
- **THEN** the result is exactly `[view_own_visits]`

#### Scenario: Resident invited elsewhere can see own invitations

- **GIVEN** a resident of unit U who is the `visitor_person` of a visit to unit W
- **WHEN** the resolver computes capabilities
- **THEN** the resident keeps the unit capabilities for U and also holds `view_own_visits`

#### Scenario: Visitor cannot create visits

- **GIVEN** a `visitor` user
- **WHEN** the user calls `POST /api/v1/private/units/:unit_id/visits`
- **THEN** the system returns `403`

#### Scenario: Visitor cannot read another person's invitation

- **GIVEN** visit A whose `visitor_person` belongs to user X
- **WHEN** user Y (a `visitor`) requests A through the invitations endpoint
- **THEN** A is not returned
