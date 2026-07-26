# Property Onboarding

## ADDED Requirements

### Requirement: Invitation token is delivered by email

The system SHALL deliver an onboarding invitation to the destination email as a single-use, time-limited link. The email SHALL identify the inviting organization by name, and MUST NOT contain the raw token outside the link, sensitive personal data (document), the holder's other emails, or any other organization the holder belongs to.

#### Scenario: Invitation email carries only a single-use link and the inviting org

- **WHEN** an invitation is issued
- **THEN** the system sends an email containing a single-use, expiring link
- **AND** the email names the inviting organization
- **AND** contains no document, no other-organization data, and no token beyond the link

#### Scenario: Delivery does not block issuance

- **GIVEN** an invitation is issued
- **WHEN** email delivery is enqueued
- **THEN** the onboarding request is persisted regardless of delivery timing

### Requirement: Acceptance creates a new account when none exists

When an invitation has no resolved account, the system SHALL create a new `User` at acceptance (the holder setting their password) and link it to the person explicitly, without relying on an implicit provisioning hook.

#### Scenario: New-account acceptance links and activates

- **GIVEN** a pending invitation with no resolved account
- **WHEN** the holder accepts and sets a password
- **THEN** the system creates a `User`, links it to the person, and activates the membership per the join rules

#### Scenario: Accepting by token confirms the email

- **GIVEN** a pending invitation
- **WHEN** the holder opens the single-use link and accepts
- **THEN** the system marks the account's email as confirmed
- **AND** does not require a separate confirmation email

#### Scenario: Successful acceptance navigates the holder to sign in

- **GIVEN** the holder successfully accepts an invitation
- **WHEN** the acceptance page is served by the SPA (Inertia)
- **THEN** the system performs a real browser navigation to the sign-in page
- **AND** does not render the sign-in page's response inside the SPA

### Requirement: Onboarding endpoints derive tenant from context

The system SHALL expose onboarding actions (invite/incorporate, revoke, resolve conflict, accept) as endpoints that derive the organization from the request context and authorize via the onboarding policy. Endpoints MUST NOT accept a tenant identifier from the client.

#### Scenario: Manager invite endpoint is authorized and tenant-safe

- **GIVEN** a manager with `manage_people`
- **WHEN** the manager posts an invitation without a tenant identifier
- **THEN** the system creates the invitation in the context organization

#### Scenario: Conflict resolution endpoint requires the dedicated capability

- **GIVEN** an actor without `resolve_identity_conflicts`
- **WHEN** the actor calls the conflict-resolution endpoint
- **THEN** the system denies the request

### Requirement: Managers can see invitation status and revoke pending requests

A manager with `manage_people` SHALL be able to see the invitation status (linked / pending / not invited) of the people in their own organization and revoke a pending invitation. This status MUST be organization-scoped and MUST NOT expose other organizations' requests. Any actor with `manage_people` may revoke (not only the issuer). The status and the revoke action are surfaced as part of the people directory, not a separate onboarding-requests screen.

#### Scenario: Manager sees invitation status scoped to their organization

- **GIVEN** onboarding requests exist in organizations O1 and O2
- **WHEN** a manager of O1 views their people directory
- **THEN** the system reports invitation status only for O1's own people

#### Scenario: Any manage_people actor can revoke a pending request

- **GIVEN** a pending request issued by another manager
- **WHEN** a different actor with `manage_people` revokes it
- **THEN** the system revokes the request
