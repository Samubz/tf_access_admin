## ADDED Requirements

### Requirement: Admin visit location step uses searchable selects

The admin visit creation form SHALL use endpoint-backed searchable select controls for the step 1 property, unit, and host fields. These controls SHALL preserve existing selection dependencies: selecting a property loads authorized units, selecting a unit loads eligible hosts and the initial status preview, and changing a parent selection clears dependent selections.

The searchable selects SHALL display only tenant-scoped and authorized options returned by visit form endpoints. Each select SHALL use 20 options as the default page size, support lazy loading more options on scroll, and keep a default selected value visible in the input. The controls SHALL preserve current disabled, loading, empty, validation, clear, and contextual-lock behavior.

#### Scenario: Property select filters properties

- **GIVEN** an authorized admin opens `/admin/visits/new`
- **AND** multiple authorized properties are available
- **WHEN** the admin types into the property searchable select
- **THEN** the property options are searched by trimmed, case-insensitive, accent-insensitive property name
- **AND** no unauthorized or cross-organization property is shown

#### Scenario: Duplicate property names remain distinguishable

- **GIVEN** two authorized properties share the same name
- **AND** the endpoint returns secondary descriptive text for them
- **WHEN** the property searchable select renders those options
- **THEN** the options can display secondary text to help the admin distinguish them
- **AND** searching still matches property name

#### Scenario: Property select lazy loads more properties

- **GIVEN** an authorized admin opens `/admin/visits/new`
- **AND** more than 20 authorized properties exist
- **WHEN** the admin opens the property searchable select without filtering and scrolls near the end
- **THEN** the next authorized property page is loaded

#### Scenario: Selecting property loads units

- **GIVEN** an authorized admin is on step 1 of the admin visit creation form
- **WHEN** the admin selects property P from the searchable select
- **THEN** the form clears any previously selected unit and host
- **AND** the form loads authorized units for P through the existing unit-loading behavior

#### Scenario: Unit select searches property units

- **GIVEN** property P is selected
- **WHEN** the admin types into the unit searchable select
- **THEN** the unit options are searched by trimmed, case-insensitive, accent-insensitive unit name within property P
- **AND** no unit outside property P or outside the admin's authorization is shown

#### Scenario: Duplicate unit names remain distinguishable

- **GIVEN** two authorized units in property P share the same name
- **AND** the endpoint returns secondary descriptive text for them
- **WHEN** the unit searchable select renders those options
- **THEN** the options can display secondary text to help the admin distinguish them
- **AND** searching still matches unit name

#### Scenario: Unit select lazy loads more units

- **GIVEN** property P has more than 20 authorized units
- **WHEN** the admin opens the unit searchable select without filtering and scrolls near the end
- **THEN** the next authorized unit page for property P is loaded

#### Scenario: Selecting unit loads hosts and status preview

- **GIVEN** an authorized admin is on step 1 with property P selected
- **WHEN** the admin selects unit U from the searchable select
- **THEN** the form clears any previously selected host
- **AND** the form loads eligible hosts for U through the existing host-loading behavior
- **AND** the form refreshes the initial status preview for U

#### Scenario: Host select searches eligible hosts

- **GIVEN** unit U has loaded eligible host options
- **WHEN** the admin types into the host searchable select
- **THEN** the host options are searched by trimmed, case-insensitive, accent-insensitive host name
- **AND** no ineligible host is shown

#### Scenario: Duplicate host names remain distinguishable

- **GIVEN** two eligible hosts share the same name
- **AND** the endpoint returns secondary descriptive text for them
- **WHEN** the host searchable select renders those options
- **THEN** the options can display secondary text to help the admin distinguish them
- **AND** searching still matches host name

#### Scenario: Single option is not auto-selected

- **GIVEN** a property, unit, or host searchable select has exactly one available option
- **WHEN** the options are loaded
- **THEN** the form does not automatically select that option
- **AND** the user must explicitly select it

#### Scenario: Clearing parent selections clears dependent values

- **GIVEN** an authorized admin has selected property P, unit U, and host H
- **WHEN** the admin clears the property select
- **THEN** the form clears unit U and host H
- **AND** the dependent status preview is cleared or reset

- **GIVEN** an authorized admin has selected unit U and host H
- **WHEN** the admin clears the unit select
- **THEN** the form clears host H
- **AND** the dependent status preview is cleared or reset

#### Scenario: Contextual creation keeps property and unit locked

- **GIVEN** the admin visit creation form is opened from an existing unit context
- **WHEN** step 1 renders
- **THEN** the property and unit searchable selects show the contextual values
- **AND** those controls remain locked according to the existing contextual create behavior
- **AND** the host searchable select remains usable after eligible hosts load

#### Scenario: Default values remain visible before their option page loads

- **GIVEN** the visit form opens with a contextual or restored property, unit, or host value
- **WHEN** the corresponding searchable select renders before that value appears in the loaded option page
- **THEN** the selected value's label is still visible in the input
- **AND** the selected value is not cleared

### Requirement: Admin visit schedule defaults to current date and start time

The admin visit creation form SHALL initialize new empty forms with `visit_date` set to the browser's current local date and `start_time` set to the browser's exact current local time when the schedule step renders on screen. The values SHALL use the existing date and time input formats.

The form SHALL NOT set a default `end_time`. Restored in-progress form state SHALL NOT be overwritten by these defaults.

#### Scenario: New visit form opens with current date and time

- **GIVEN** an admin opens `/admin/visits/new` without restored form state
- **WHEN** the schedule step is reached
- **THEN** the date input is preloaded with the browser's current local date
- **AND** the start time input is preloaded with the browser's exact current local time in `HH:mm` format
- **AND** the start time is not rounded to a time interval
- **AND** the end time input remains empty

#### Scenario: Defaults are included in summary before manual edit

- **GIVEN** an admin opens a new empty visit form
- **WHEN** the admin reaches the authorization summary before changing schedule values
- **THEN** the summary uses the preloaded current date and start time

#### Scenario: Restored form values are preserved

- **GIVEN** an admin has an in-progress visit creation form saved in browser session state
- **WHEN** the admin returns to `/admin/visits/new`
- **THEN** the restored visit date and start time remain unchanged
- **AND** they are not replaced by the current date/time defaults

#### Scenario: Server validation remains authoritative

- **GIVEN** a client submits a visit with invalid or missing schedule values
- **WHEN** the backend processes the visit creation request
- **THEN** existing server-side visit schedule validation still determines whether the visit is accepted
