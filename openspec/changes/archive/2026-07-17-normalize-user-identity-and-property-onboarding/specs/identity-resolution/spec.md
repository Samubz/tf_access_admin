# Identity Resolution

## Purpose

Define how the system resolves a person to an authentication account using the confirmed email as the transversal identity key, how it classifies weaker signals, prevents mixing distinct identities, records conflicts, and answers cross-organization queries without leaking information between tenants.

## ADDED Requirements

### Requirement: Email is the transversal identity key

The system SHALL treat a `User`'s email as the canonical, transversal identifier of the authentication account. Resolving a `Person` to an existing `User` by email SHALL be automatic and server-side and MUST NOT require an "is this you?" challenge. The account is linked regardless of whether the email is already confirmed; confirmation gates application usage (see `user-account-linking`), not identity linking.

#### Scenario: Person resolves to an existing account by email

- **GIVEN** a `User` exists with an email, confirmed or not
- **WHEN** a flow references a person carrying the same email
- **THEN** the system resolves the person to that existing `User`
- **AND** does not create a second account for the same email

#### Scenario: Ownership assumed for the registering holder

- **GIVEN** an email registered by the account holder
- **WHEN** the account is resolved later
- **THEN** the system treats the holder as the owner of that email
- **AND** an email change requires a separate reverification request

### Requirement: Weaker signals never establish identity

The system SHALL NOT treat two records as the same person based solely on a shared name or a shared phone. Org-asserted data (for example, an email typed by a manager during import) MUST NOT overwrite an existing `Person`'s or `User`'s data on the basis of that assertion alone.

#### Scenario: Shared name does not imply same person

- **GIVEN** two records sharing only a name
- **WHEN** resolution runs
- **THEN** the system does not treat them as the same person

#### Scenario: Shared phone does not imply same person

- **GIVEN** two records sharing only a phone number
- **WHEN** resolution runs
- **THEN** the system does not treat them as the same person

#### Scenario: Org-asserted email does not overwrite identity

- **GIVEN** an existing identity
- **WHEN** an organization supplies conflicting data alongside a matching email
- **THEN** the system resolves the account by email
- **AND** does not overwrite the existing person or user data with the org-supplied values

### Requirement: Manager remains email-blind

When resolving a person, the system SHALL NOT disclose to the manager whether the email already belongs to an existing account, nor any other organization the account participates in. The manager's experience MUST be identical whether or not a matching account exists.

#### Scenario: Existing account is not disclosed to the manager

- **GIVEN** a manager in organization O1 invites an email that already has an account also present in organization O2
- **WHEN** the system responds
- **THEN** the response is neutral (for example, "invitation sent")
- **AND** does not reveal that an account exists, nor O2's name, properties, units, roles, history, or emails

#### Scenario: Identical experience for new and existing accounts

- **WHEN** a manager invites an email
- **THEN** the manager sees the same neutral outcome regardless of whether a matching account exists

### Requirement: Identity conflict recording

The system SHALL record an identity conflict without changing any association and SHALL require explicit resolution by an authorized actor. The following conflict cases MUST be handled: (1) same document and same email; (2) same document, different email; (3) different document, same email; (4) existing person without `User`; (5) existing person with `User`; (6) `User` linked to a different `Person` in the same organization; (7) partial data without document; (8) name-only match; (9) phone-only match; (10) pending invitation; (11) active membership; (12) revoked membership; (13) soft-deleted person; (14) deactivated user; (15) expired request; (16) manager attempting to reference an account from another organization; (17) two simultaneous requests for the same person; (18) email change while an invitation is pending.

#### Scenario: Same document, different email within organization

- **GIVEN** a document matches an existing person in the organization
- **AND** the supplied email differs from the person's known email
- **WHEN** the flow runs
- **THEN** the system records a conflict
- **AND** changes no association until explicitly resolved

#### Scenario: User already linked to a different Person in the same organization

- **GIVEN** a `User` already linked to a `Person` in an organization
- **WHEN** a flow attempts to link it to a second person in that organization
- **THEN** the system records a conflict and requires explicit resolution

#### Scenario: Two simultaneous requests for the same person

- **GIVEN** two onboarding requests are created concurrently for the same person and relationship
- **WHEN** they are processed
- **THEN** the system keeps a single pending request
- **AND** treats the duplicate idempotently

### Requirement: Conflict resolution requires a dedicated capability

The system SHALL gate resolution of global identity conflicts behind a dedicated capability (`resolve_identity_conflicts`), separate from `manage_people`. A property manager MUST NOT resolve identity conflicts by virtue of managing people. The capability MAY default to super admin and be delegable to a trusted role without granting access to other organizations' data.

#### Scenario: Property manager cannot resolve a conflict

- **GIVEN** a manager with `manage_people` but without `resolve_identity_conflicts`
- **WHEN** the manager attempts to resolve an identity conflict
- **THEN** the system denies the action

#### Scenario: Authorized actor resolves a conflict without cross-tenant exposure

- **GIVEN** an actor with `resolve_identity_conflicts`
- **WHEN** the actor resolves a conflict
- **THEN** the system applies the resolution
- **AND** does not expose other organizations' data during resolution
