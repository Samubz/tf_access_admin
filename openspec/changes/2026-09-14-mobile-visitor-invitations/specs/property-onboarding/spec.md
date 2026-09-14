# Property Onboarding

## ADDED Requirements

### Requirement: Visitor onboarding relationship

The system SHALL support `visitor` as a requested relationship on an `OnboardingRequest`. A `visitor` request MUST NOT reference a unit or residential property, and accepting it SHALL create an active `OrganizationMembership` with role `visitor` in the inviting organization.

#### Scenario: Visitor accepts and gets a visitor membership

- **GIVEN** a pending `visitor` onboarding request for person P in organization O
- **WHEN** the holder accepts the single-use link and sets a password
- **THEN** a confirmed `User` is created and linked to P
- **AND** P's user holds an active `visitor` membership in O
- **AND** the user can authenticate through the private API for O

#### Scenario: Visitor request rejects unit scope

- **WHEN** a `visitor` onboarding request is issued with a `unit_id`
- **THEN** the request is invalid

### Requirement: Visit invitation email delivers the acceptance link

When a visit is created for a visitor without account, the system SHALL send an email that names the inviting organization, the host's display name, the property, the unit and the scheduled date/time, plus the single-use acceptance link. The email MUST NOT include documents, phone numbers or the raw token outside the link.

#### Scenario: Email content

- **WHEN** the visit invitation email is rendered
- **THEN** it contains organization name, host name, property, unit, date/time and the acceptance link
- **AND** contains no document number, phone number or token outside the link

#### Scenario: Email is localized

- **GIVEN** the inviting organization's default locale is `pt`
- **WHEN** the email is rendered
- **THEN** all texts use the `pt` locale
