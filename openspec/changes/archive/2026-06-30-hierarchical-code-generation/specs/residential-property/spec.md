# residential-property Delta Specification

## ADDED Requirements

### Requirement: Residential property code is always system-derived

The system SHALL always derive `ResidentialProperty#code` on create. The derived code MUST use the property `property_type` abbreviation and a slug of the property `name`, remain within the alphanumeric-hyphen format, and be unique per organization among non-deleted properties. Any client-submitted `code` MUST be stripped and replaced by the derived value.

#### Scenario: Code is derived on create

- **GIVEN** organization O has no property with code `cdo-parque-central`
- **WHEN** a property is created in O with `name: "Parque Central"` and `property_type: condominium`
- **THEN** the persisted `code` is `cdo-parque-central`

#### Scenario: Derived code collision receives suffix

- **GIVEN** organization O already has a non-deleted property with `code: cdo-parque-central`
- **WHEN** another property in O is created whose type and name derive the same base code
- **THEN** the new property receives `code: cdo-parque-central-2`

#### Scenario: Client-submitted code is ignored

- **WHEN** a property is created via a user-facing form with `code: "MY-BLD"` in the request
- **THEN** the persisted `code` is the server-derived value, not `MY-BLD`

#### Scenario: Property rename does not change code

- **GIVEN** property P has `code: cdo-parque-central`
- **WHEN** P is renamed through a supported update path
- **THEN** P keeps `code: cdo-parque-central`
