# Property Onboarding

## Purpose

Define how a person is incorporated into a new organization, property, or unit. Incorporation covers both inviting a person who has no account and joining an existing account (resolved by confirmed email). The activation of the resulting membership depends on what the join grants: a client-only (self-scoped) join is active immediately and declinable by the holder; a join that grants operational roles or sensitive access is pending until the holder explicitly accepts, and is revocable afterward.

## ADDED Requirements

### Requirement: Join-activation rule

The system SHALL determine membership activation by the sensitivity of what the join grants. A join that grants only client-level, self-scoped capabilities SHALL be created active immediately, visible to the holder, and declinable by the holder. A join that grants operational roles or access to sensitive data SHALL be created pending and MUST require the holder's explicit acceptance before it becomes active.

#### Scenario: Client-only join is active and declinable

- **GIVEN** a join that grants only the client role (self-scoped)
- **WHEN** the person is incorporated into the organization
- **THEN** the membership is created active immediately
- **AND** is visible to the holder
- **AND** can be declined or revoked by the holder

#### Scenario: Operational-role join requires acceptance

- **GIVEN** a join that grants one or more operational roles
- **WHEN** the person is incorporated
- **THEN** the membership is created pending
- **AND** does not become active until the holder explicitly accepts

#### Scenario: Sensitive-access join requires acceptance

- **GIVEN** a join that grants access to sensitive data or operational capabilities
- **WHEN** the person is incorporated
- **THEN** the membership is created pending
- **AND** does not grant access until the holder accepts

#### Scenario: Operational role may be the first contact

- **GIVEN** a person with no prior membership in the organization
- **WHEN** the person is invited directly with an operational role
- **THEN** the system creates a pending onboarding request
- **AND** on acceptance creates the membership and the operational role together

### Requirement: Holder controls their memberships and roles

The system SHALL let the account holder view their memberships and roles across organizations (self-scope), decline or revoke a client-level membership, and accept or reject each operational role granted to them. A holder MAY revoke an operational role after accepting it.

#### Scenario: Holder declines a client membership

- **GIVEN** an active client-level membership created by incorporation
- **AND** the organization owns the person's `Person` record and its ownerships/occupancies
- **WHEN** the holder declines it
- **THEN** the membership is revoked
- **AND** the `User`↔`Person` link is removed so no user access remains
- **AND** the `Person` and its ownerships/occupancies remain owned by the organization
- **AND** the decline is audited and reversible

#### Scenario: Holder accepts an operational role

- **GIVEN** a pending operational role
- **WHEN** the holder accepts it
- **THEN** the role becomes active

#### Scenario: Holder revokes a previously accepted role

- **GIVEN** an operational role the holder previously accepted
- **WHEN** the holder revokes it
- **THEN** the role no longer grants access

### Requirement: Only the manager role assigns or revokes roles

The system SHALL restrict assigning and revoking roles to the manager role. Other roles MUST NOT assign or revoke roles.

#### Scenario: Non-manager cannot assign a role

- **GIVEN** an actor without the manager role
- **WHEN** the actor attempts to assign or revoke a role
- **THEN** the system denies the action

#### Scenario: Manager assigns a role

- **GIVEN** an actor with the manager role
- **WHEN** the actor assigns an operational role through an onboarding request
- **THEN** the system permits it

### Requirement: Operational roles are confirmable

The system SHALL make an operational role assignment (`StaffAssignment`) carry a confirmation state and a confirmation timestamp. An operational role assignment SHALL be created unconfirmed and MUST NOT grant access until the holder confirms it. An existing active client membership is unchanged while an operational role is pending confirmation.

#### Scenario: Operational role created unconfirmed

- **WHEN** a manager assigns an operational role
- **THEN** the system creates the `StaffAssignment` in an unconfirmed state
- **AND** the role grants no access until confirmed

#### Scenario: Confirmation stamps the timestamp and activates the role

- **GIVEN** an unconfirmed `StaffAssignment`
- **WHEN** the holder confirms it
- **THEN** the system records the confirmation timestamp
- **AND** the role becomes effective

#### Scenario: Pending operational role does not affect active client membership

- **GIVEN** a holder with an active client membership
- **WHEN** a manager assigns them a pending operational role
- **THEN** the client membership remains active and unchanged

### Requirement: Re-invitation after revocation

The system SHALL allow inviting or incorporating a person again after a previous membership or role was revoked, without being blocked by uniqueness on active or invited records. The new invitation reuses the confirmable flow.

#### Scenario: Revoked membership can be re-invited

- **GIVEN** a person whose membership in an organization was revoked
- **WHEN** the person is invited again to that organization
- **THEN** the system creates a new invitation
- **AND** is not blocked by the revoked record

### Requirement: Onboarding request entity

The system SHALL provide an onboarding request that records the organization, an optional property, an optional unit, the person, the resolved user when one exists, the requested relationship and roles, the requesting actor, a status, an expiration timestamp, a secure token digest when a token is issued, an optional conflict reason, minimal metadata, and a change history.

#### Scenario: Request captures scope and requester

- **WHEN** an onboarding request is created
- **THEN** it records organization, optional property, optional unit, person, resolved user when present, requested relationship and roles, requesting actor, status, and expiration

#### Scenario: Token stored only as digest

- **WHEN** an onboarding request issues a token
- **THEN** the system stores only the token digest
- **AND** never persists the token in cleartext

### Requirement: Acceptance verifies context after authentication

For pending joins, the system SHALL create the granted access only after the holder authenticates and the context is verified. Possession of an invitation link alone MUST NOT grant access.

#### Scenario: Possession of the link is insufficient

- **WHEN** a request link is opened without the holder authenticating as the email owner
- **THEN** the system does not grant access

### Requirement: Expiration and revocation of pending requests

The system SHALL require an expiration on each pending onboarding request and SHALL allow an authorized actor to revoke it. Expired and revoked requests MUST NOT grant access.

#### Scenario: Expired request grants nothing

- **GIVEN** a pending onboarding request past its expiration
- **WHEN** the holder attempts to accept it
- **THEN** the system rejects the acceptance

#### Scenario: Revoked request grants nothing

- **GIVEN** a pending onboarding request
- **WHEN** an authorized actor revokes it
- **THEN** the request can no longer be accepted

### Requirement: Idempotent pending requests

The system SHALL NOT create duplicate pending onboarding requests for the same organization, person, requested relationship, and scope.

#### Scenario: Duplicate pending request is idempotent

- **GIVEN** a pending onboarding request for a person and relationship
- **WHEN** an equivalent request is created
- **THEN** the system keeps a single pending request

### Requirement: Safe delivery controls

The system SHALL require additional verification when the known email changes while an invitation is pending, and MUST NOT attach sensitive information to invitation emails. Invitation tokens SHALL be single-use and time-limited.

#### Scenario: Email change during a pending invitation

- **GIVEN** a pending invitation for a known email
- **WHEN** the known email changes
- **THEN** the system requires additional verification before proceeding

#### Scenario: No sensitive data in invitation email

- **WHEN** an invitation email is sent
- **THEN** it does not include sensitive personal data beyond a single-use, time-limited link
