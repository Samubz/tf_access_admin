## ADDED Requirements

### Requirement: Searchable select searches endpoint-backed options

The system SHALL provide a reusable searchable select control that lets users type to search options supplied by a caller-provided option loader. The control SHALL expose select-like behavior through a bound value, visible selected label, placeholder, disabled state, loading state, empty state, clear action, and validation state.

The control SHALL support a default page size of 20 options, lazy loading of additional pages when the user scrolls, and query-based searching. The control MUST NOT fetch records on its own except through the caller-provided loader, and it MUST NOT reveal options that were not returned by that loader.

Typed search requests SHALL be debounced by a short delay. If an option request fails, the control SHALL keep the current selected value and selected label visible while showing a recoverable error or empty state.

#### Scenario: User searches options by typing

- **GIVEN** a searchable select has an option loader
- **WHEN** the user types text into the control
- **THEN** the control requests options matching the trimmed search text
- **AND** matching is case-insensitive and accent-insensitive according to the endpoint contract
- **AND** options not returned by the loader are not shown

#### Scenario: Typed search is debounced

- **GIVEN** a searchable select is enabled
- **WHEN** the user types several characters quickly
- **THEN** the control waits briefly before sending the search request
- **AND** avoids sending one endpoint request per keystroke

#### Scenario: Initial options are available

- **GIVEN** a searchable select renders enabled with no typed query
- **WHEN** its initial options load
- **THEN** at least 20 available options are shown when that many authorized options exist

#### Scenario: User scrolls to load more options

- **GIVEN** a searchable select is open with more unfiltered options available
- **WHEN** the user scrolls near the end of the current option list
- **THEN** the control requests the next page
- **AND** appends the returned options without clearing the selected value

#### Scenario: Option request fails

- **GIVEN** a searchable select has a selected value
- **WHEN** the option loader request fails
- **THEN** the control shows a recoverable error or empty state
- **AND** the selected value and selected label remain visible
- **AND** the bound value is not cleared

#### Scenario: User selects an option

- **GIVEN** a searchable select is enabled
- **WHEN** the user chooses one visible option
- **THEN** the control updates its bound value to that option's value
- **AND** the selected option label is displayed in the closed control

#### Scenario: Selected default value remains visible

- **GIVEN** a searchable select has a bound value before its current page of options is loaded
- **AND** the caller provides or loads the selected option label
- **WHEN** the control renders closed
- **THEN** the selected option label is displayed in the input
- **AND** the value is not cleared merely because the selected option is not present in the current page

#### Scenario: User clears the selected value

- **GIVEN** a searchable select has a selected value
- **WHEN** the user activates the clear action
- **THEN** the control clears its bound value
- **AND** the visible selected label is removed
- **AND** parent form dependency handlers can react to the cleared value

#### Scenario: Duplicate labels can show secondary text

- **GIVEN** a searchable select receives multiple options with the same label
- **AND** those options include secondary descriptive text
- **WHEN** the option list renders
- **THEN** the control can show the secondary text to distinguish the options
- **AND** search still matches the configured searchable name text

#### Scenario: No filtered results

- **GIVEN** a searchable select has searched through its option loader
- **WHEN** the user's filter text matches no option
- **THEN** the control shows an empty-state message
- **AND** the bound value is not changed merely because the filter has no results

#### Scenario: Loading state blocks selection

- **GIVEN** a searchable select is loading options
- **WHEN** the user opens the control
- **THEN** the control shows a loading state
- **AND** new option selection is disabled until loading finishes

#### Scenario: Disabled state prevents interaction

- **GIVEN** a searchable select is disabled
- **WHEN** the user attempts to open or type into the control
- **THEN** no option list is opened
- **AND** the bound value remains unchanged

### Requirement: Searchable select is keyboard accessible

The reusable searchable select control SHALL support keyboard interaction for opening the option list, moving between visible options, selecting the highlighted option, closing the list, and preserving focus predictably.

#### Scenario: Keyboard user selects an option

- **GIVEN** a searchable select is focused and enabled
- **WHEN** the user opens it with the keyboard, navigates to an option, and confirms selection
- **THEN** the highlighted option becomes the selected value
- **AND** focus remains in a predictable form-control location

#### Scenario: Escape closes without changing value

- **GIVEN** a searchable select is open
- **AND** it already has a selected value
- **WHEN** the user presses Escape
- **THEN** the option list closes
- **AND** the selected value remains unchanged

### Requirement: Searchable select can be reused across forms

The searchable select control SHALL be generic and independent of the admin visit form. Callers SHALL be able to provide option values, labels, optional descriptions, placeholder/loading/empty text, disabled state, validation state, an option loader, pagination metadata, and selected-value display data without depending on visit-specific types.

#### Scenario: Caller provides custom option data

- **GIVEN** a form outside visit creation provides generic options with values and labels
- **WHEN** the searchable select renders those options
- **THEN** the control can filter and select among them without requiring visit-specific fields

#### Scenario: Caller provides validation state

- **GIVEN** a form field using the searchable select has a validation error
- **WHEN** the control renders
- **THEN** the control exposes an invalid visual and accessibility state supplied by the caller
