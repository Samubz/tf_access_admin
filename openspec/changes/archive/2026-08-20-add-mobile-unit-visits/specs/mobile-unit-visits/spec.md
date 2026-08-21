## ADDED Requirements

### Requirement: Unit visits listing endpoint for mobile clients
The system SHALL provide `GET /api/v1/mobile/residential_property/:id/unit/:unit_id/visitas`, which returns an array of the `Visit` records scheduled for the requested unit on a given day. The day SHALL be specified by an optional `day` query parameter (`YYYY-MM-DD`); when omitted, the day SHALL default to "today" computed in the requested residential property's `timezone`. A `day` value that is not a valid `YYYY-MM-DD` date SHALL respond `422 Unprocessable Entity`. The authenticated user SHALL only receive a response when their `Person` record has an active `UnitOccupancy` on the requested unit — an active `UnitOwnership` alone SHALL NOT be sufficient. The requested residential property SHALL only be considered when its `status` is `active`; the requested unit SHALL only be considered when its `status` is `available` or `occupied`, and it SHALL belong to the requested residential property. Every one of the following SHALL respond identically `404 Not Found`, with no distinguishing signal between causes: the residential property not existing, the unit not existing or not belonging to the residential property, the residential property's `status` not being `active`, the unit's `status` not being `available` or `occupied`, or the user having no active `UnitOccupancy` on the unit. When all of the above conditions are satisfied, the system SHALL respond `200 OK` with an array — even when that array is empty, an empty array is a valid, non-error result and SHALL NOT be treated as `404`. Each array entry SHALL contain `visitor_name` (the visitor `Person`'s `display_name`), `checked_in_at`, `checked_out_at` (both nullable), and `status` (the raw `Visit#status` value). All `Visit` statuses SHALL be included with no filtering by status.

#### Scenario: Resident fetches today's visits by default
- **WHEN** an authenticated user with an active `UnitOccupancy` on unit `U` (belonging to active residential property `P`, itself `available`/`occupied`) calls `GET /api/v1/mobile/residential_property/P/unit/U/visitas` with no `day` parameter, and `U` has one `Visit` scheduled today (in `P`'s timezone)
- **THEN** the system responds `200 OK` with an array containing one entry, with `visitor_name`, `checked_in_at`, `checked_out_at`, and `status` matching that visit

#### Scenario: Resident fetches visits for an explicit day
- **WHEN** an authenticated resident of unit `U` calls the endpoint with `day=2026-08-25`
- **THEN** the system responds `200 OK` with an array containing only visits whose `scheduled_at`, interpreted in residential property `P`'s timezone, falls on 2026-08-25

#### Scenario: Day boundary is computed in the residential property's timezone, not UTC
- **WHEN** the requested residential property has `timezone: "America/Santiago"` and a `Visit` is `scheduled_at` a time that falls on one calendar day in `America/Santiago` but a different calendar day in UTC
- **THEN** requesting `day` for the `America/Santiago` calendar date includes that visit, and requesting `day` for the UTC calendar date (when it differs) does not

#### Scenario: Malformed day parameter is rejected
- **WHEN** an authenticated resident of unit `U` calls the endpoint with a `day` value that is not a valid `YYYY-MM-DD` date (e.g. `not-a-date`, `2026-13-40`)
- **THEN** the system responds `422 Unprocessable Entity`

#### Scenario: All visit statuses are included
- **WHEN** unit `U` has visits with statuses `pending`, `authorized`, `checked_in`, `checked_out`, `cancelled`, `rejected`, and `expired`, all scheduled on the requested day
- **THEN** all seven visits appear in the response array, each with its own raw `status` value

#### Scenario: No visits scheduled for the day is a successful empty result
- **WHEN** an authenticated resident of unit `U` (in an active property, with `U` `available`/`occupied`) calls the endpoint for a day with zero scheduled visits
- **THEN** the system responds `200 OK` with an empty array, not `404 Not Found`

#### Scenario: Owner without active occupancy is denied
- **WHEN** a user's `Person` has an active `UnitOwnership` on unit `U` but no active `UnitOccupancy` on it
- **THEN** the system responds `404 Not Found`

#### Scenario: Inactive occupancy is denied
- **WHEN** a user's `Person` has a `UnitOccupancy` on unit `U` whose `status` is not `active`
- **THEN** the system responds `404 Not Found`

#### Scenario: Residential property id does not exist
- **WHEN** an authenticated user calls the endpoint for a `:id` that does not correspond to any residential property
- **THEN** the system responds `404 Not Found`

#### Scenario: Unit id does not exist or belongs to a different residential property
- **WHEN** an authenticated user calls the endpoint with a `:unit_id` that does not correspond to any unit within residential property `:id`, including a unit that exists but belongs to a different residential property
- **THEN** the system responds `404 Not Found`, identically to the nonexistent-unit case

#### Scenario: Residential property is not active
- **WHEN** an authenticated resident of unit `U` calls the endpoint for a residential property whose `status` is `draft`, `created`, `configured`, `inactive`, or `archived`
- **THEN** the system responds `404 Not Found`, regardless of the user's occupancy on `U`

#### Scenario: Unit has an ineligible status
- **WHEN** an authenticated user has an active `UnitOccupancy` on unit `U`, but `U`'s `status` is `inactive`, `maintenance`, or `archived`
- **THEN** the system responds `404 Not Found`

#### Scenario: Unauthenticated request is rejected
- **WHEN** a request to `GET /api/v1/mobile/residential_property/:id/unit/:unit_id/visitas` is made with no `Authorization` header, or an invalid/expired JWT
- **THEN** the system responds `401 Unauthorized`
