## ADDED Requirements

### Requirement: Summary and confirmation use persisted wizard data

The setup wizard SHALL render step 4 summary and step 5 confirmation from the current persisted database state for the authorized draft property. Property details, section counts, unit counts, and visible nested summaries MUST be derived from records scoped to the current organization and residential property, not from client-side estimates, previous form state, or partial generation previews.

Deleted sections and soft-deleted units MUST be excluded from ordinary visible summary and confirmation totals. Units associated with soft-deleted sections MUST NOT be counted or shown, even when the unit itself is not soft-deleted. The summary and confirmation views MUST use the same persisted data contract so the user reviews and confirms the same counts.

The setup wizard MUST NOT ask for, require, or display an estimated unit count as a property data input, and step 1 validation MUST NOT block submission on an estimated unit count. Unit totals shown in summary, confirmation, and the post-confirmation completed view SHALL represent persisted non-deleted units associated with eligible property sections. No wizard prop contract, at any step, SHALL retain an "estimated unit count" field once a persisted count is available.

#### Scenario: Summary unit total matches persisted units

- **GIVEN** an authorized user is setting up draft property P in organization O
- **AND** P has 24 non-deleted persisted units associated with eligible sections
- **WHEN** the user opens the step 4 summary
- **THEN** the unit total shown in the summary is 24
- **AND** the total is not replaced by an estimated unit count or by the number of units in a partial preview

#### Scenario: Confirmation unit total matches summary

- **GIVEN** the step 4 summary for draft property P shows 24 non-deleted persisted units associated with sections
- **WHEN** the user opens the step 5 confirmation
- **THEN** the confirmation view shows the same 24-unit total
- **AND** the confirmation view does not recompute a different total from stale client state

#### Scenario: Property data summary reflects saved property fields

- **GIVEN** draft property P has saved name, type, address, status, structure, and unit records
- **WHEN** the step 4 summary renders "Datos de la propiedad"
- **THEN** the displayed property data reflects P's persisted values
- **AND** structure and unit totals are derived from P's current non-deleted persisted associations

#### Scenario: Estimated unit input is not shown

- **GIVEN** an authorized user opens the property data step
- **WHEN** the property data form renders
- **THEN** no estimated unit count input is shown
- **AND** no later summary, confirmation, or completed value is derived from an estimated unit count

#### Scenario: Property data step submits without an estimated unit count

- **GIVEN** an authorized user completes the property data step
- **WHEN** the user submits step 1 without an estimated unit count value
- **THEN** step 1 validation does not require or block on an estimated unit count
- **AND** the draft property is saved successfully

#### Scenario: Completed view shows the same persisted totals as confirmation

- **GIVEN** the step 5 confirmation for draft property P shows a 24-unit persisted total
- **WHEN** the user confirms and the wizard renders the completed view
- **THEN** the completed view shows the same 24-unit persisted total
- **AND** the completed view does not read or display an estimated unit count

#### Scenario: Summary excludes records outside the current property

- **GIVEN** organization O has draft property P with 24 non-deleted persisted units associated with sections
- **AND** organization O has another property Q with additional units
- **WHEN** the user opens P's step 4 summary or step 5 confirmation
- **THEN** only units belonging to P are counted
- **AND** Q's units are not included

#### Scenario: Summary preserves tenant isolation

- **GIVEN** draft property P belongs to organization O
- **AND** another organization Q has properties, sections, and units
- **WHEN** an authorized user in organization O opens P's summary or confirmation
- **THEN** no property, section, or unit data from organization Q is counted or displayed

#### Scenario: Soft-deleted units are excluded

- **GIVEN** draft property P has 24 non-deleted persisted units associated with sections
- **AND** P has 2 soft-deleted units
- **WHEN** the user opens the summary or confirmation
- **THEN** the ordinary visible unit total is 24
- **AND** the soft-deleted units are not shown in the nested unit preview

#### Scenario: Units under soft-deleted sections are excluded

- **GIVEN** draft property P has 24 non-deleted persisted units associated with non-deleted sections
- **AND** P has a soft-deleted section containing 3 non-deleted units
- **WHEN** the user opens the summary or confirmation
- **THEN** the ordinary visible unit total is 24
- **AND** the units under the soft-deleted section are not shown in the nested unit preview

#### Scenario: Summary refreshes after step 3 mutations

- **GIVEN** an authorized user creates, edits, or soft-deletes units in step 3
- **WHEN** the user navigates to the step 4 summary
- **THEN** the summary reflects the persisted result of those mutations
- **AND** stale pre-mutation counts are not shown

#### Scenario: Soft-delete reduces persisted unit totals

- **GIVEN** draft property P has 24 non-deleted persisted units associated with sections
- **WHEN** an authorized user soft-deletes one unit in step 3 and opens the summary
- **THEN** the ordinary visible unit total is 23
- **AND** the confirmation view shows the same 23-unit total

#### Scenario: Confirmation reloads persisted totals independently

- **GIVEN** the step 4 summary for draft property P shows 24 non-deleted persisted units associated with sections
- **AND** the persisted unit total changes to 23 before confirmation renders
- **WHEN** the user opens the step 5 confirmation
- **THEN** the confirmation view reads the current persisted total
- **AND** the confirmation view shows 23 units instead of reusing stale step 4 state
