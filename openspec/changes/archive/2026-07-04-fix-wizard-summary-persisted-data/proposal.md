## Why

The property setup wizard summary and confirmation sections can present stale or derived client-side values that do not match the persisted database state. This causes user-facing inconsistencies such as showing 1 unit for a property that actually has 24 persisted units.

## What Changes

- Make the step 4 summary and step 5 confirmation data source authoritative from persisted database records.
- Correct the "Datos de la propiedad" summary so counts and property details reflect the current saved draft property, sections, and units.
- Ensure unit totals, section totals, and nested preview details are computed from non-deleted persisted records scoped to the current organization and draft property, with units counted from their section associations.
- Remove the estimated unit count input from the setup flow because it is not business-authoritative and can conflict with persisted unit data.
- Refresh or reload persisted summary props after wizard mutations so the UI cannot confirm with stale counts.
- Add regression coverage for the known mismatch case where persisted units exceed the currently displayed summary count.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `property-setup-wizard`: Summary and confirmation requirements now require persisted database-backed data, including accurate unit counts and property detail summaries.

## Bounded Context

Affected domains and integration points:

- Property setup wizard steps 4 and 5.
- Residential property draft state.
- Property sections and units associated with those sections in the draft property.
- Inertia props consumed by Vue wizard summary and confirmation components.

Affected models, services, and tables:

- Models: `ResidentialProperty`, `PropertySection`, `Unit`.
- Services/serializers/controllers: property setup wizard serialization and controller actions that provide summary and confirmation props.
- Tables: `residential_properties`, `property_sections`, `units`.

Dependencies on other OpenSpec changes:

- Depends on the implemented manual unit work being available when the wizard has persisted section-associated manual units, especially the case where 24 units exist after step 3.

## Impact

- Tenant isolation remains mandatory: all counts and records must be scoped through the current organization and current draft property.
- Authorization remains unchanged, but summary/confirmation data must not expose records outside the user's authorized property context.
- No database schema changes are expected.
- Frontend changes are expected in the wizard summary, confirmation, and post-confirmation completed views (including the shared units preview panel) and related typed props.
- Backend changes are expected in the serializer/controller path that builds persisted wizard summary data.
- Step 1 property data form changes are expected to remove the non-authoritative estimated unit input and related summary usage.

## Non-goals

- Do not redesign the wizard layout.
- Do not change unit creation, section creation, or confirmation lifecycle behavior.
- Do not add new unit generation modes.
- Do not include deleted units or deleted sections in visible counts.
