# Organization Membership

## Purpose

Define how a single account participates in multiple organizations without mixing permissions or contextual information, how memberships are visible and declinable by the holder, how relationships are treated idempotently, and how access is revoked per organization without affecting others.

## ADDED Requirements

### Requirement: Independent membership per organization

The system SHALL represent participation in each organization with an independent `OrganizationMembership`, with permissions and roles scoped per organization.

#### Scenario: Permissions do not leak across organizations

- **GIVEN** a user with roles in organization O1
- **WHEN** the user acts in organization O2
- **THEN** the O1 roles do not grant permissions in O2

#### Scenario: Access to own units within an organization

- **GIVEN** a user linked to a person with ownerships in an organization
- **WHEN** the user accesses that organization
- **THEN** the user's capabilities derive from that organization's active relationships only

### Requirement: Memberships are visible and declinable by the holder

The system SHALL make each membership visible to the account holder (self-scope) and allow the holder to decline or leave a client-level membership. Operational roles within a membership follow the accept/revoke rules in `property-onboarding`.

#### Scenario: Client membership appears to the holder

- **GIVEN** a client-level membership created by incorporation
- **WHEN** the holder views their account
- **THEN** the membership is listed among their memberships
- **AND** the holder can decline or leave it

### Requirement: Revocation is organization-scoped

The system SHALL allow revoking a user's access in one organization without affecting the user's memberships in other organizations.

#### Scenario: Revoking in one organization preserves others

- **GIVEN** a user with active memberships in O1 and O2
- **WHEN** access is revoked in O1
- **THEN** the O2 membership remains active

### Requirement: Idempotent existing relationships

The system SHALL treat a request for a relationship that already exists as idempotent, creating no duplicate and reporting the existing state without revealing other organizations' data.

#### Scenario: Existing membership is idempotent

- **GIVEN** a person already has an active membership in the organization
- **WHEN** an incorporation is requested for the same organization
- **THEN** the system creates no duplicate membership
- **AND** reports the existing state neutrally

#### Scenario: Existing unit relationship is idempotent

- **GIVEN** a person already relates to a unit
- **WHEN** the same relationship is requested again
- **THEN** the system creates no duplicate

### Requirement: Membership uniqueness

The system SHALL enforce a single active or invited membership per person and organization.

#### Scenario: Duplicate active membership rejected

- **GIVEN** an active membership for a person in an organization
- **WHEN** a second active membership is created for the same person and organization
- **THEN** the system rejects it
