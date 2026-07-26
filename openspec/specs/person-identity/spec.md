# person-identity Specification

## Purpose
TBD - created by archiving change normalize-user-identity-and-property-onboarding. Update Purpose after archive.
## Requirements
### Requirement: Two-level identity model

The system SHALL treat `User` as the global authentication account and `Person` as the canonical identity within a single organization. The system MUST NOT introduce a global `Person` identity nor parallel identity tables.

#### Scenario: User is global

- **GIVEN** a person participates in two organizations
- **WHEN** the system represents their authentication account
- **THEN** a single global `User` record MAY be used across both organizations
- **AND** a separate `Person` record exists per organization

#### Scenario: Person is per-organization

- **GIVEN** the same document exists in two organizations
- **WHEN** the system resolves identity in each organization
- **THEN** each organization has its own independent `Person` record
- **AND** neither `Person` exposes the other

### Requirement: Person–User cardinality

The system SHALL allow a `User` to be linked to at most one active `Person` per organization, and a `Person` to be linked to at most one `User`.

#### Scenario: User linked to at most one Person per organization

- **GIVEN** a `User` already linked to an active `Person` in an organization
- **WHEN** a flow attempts to link the same `User` to a second active `Person` in that organization
- **THEN** the system rejects the operation
- **AND** does not create a duplicate link

#### Scenario: Person linked to at most one User

- **GIVEN** a `Person` already linked to a `User`
- **WHEN** a flow attempts to link a different `User` to that `Person`
- **THEN** the system rejects the operation
- **AND** preserves the existing link

#### Scenario: Same User across organizations is intentional

- **GIVEN** a `User` linked to a `Person` in organization O1
- **WHEN** the same `User` is incorporated into organization O2
- **THEN** the system links the `User` to a distinct `Person` in O2
- **AND** the two `Person` records remain independent

### Requirement: Confirmed email groups a person's identities across organizations

The system SHALL use the `User`'s confirmed email as the transversal key that groups a person's `Person` records across organizations. Grouping SHALL occur through the `Person`→`User` link established by confirmed-email resolution; sharing an email string alone MUST NOT group records until a link is established.

#### Scenario: Linked persons group under one account

- **GIVEN** a `User` with a confirmed email linked to a `Person` in O1 and a `Person` in O2
- **WHEN** the account's identities are grouped
- **THEN** both `Person` records belong to the same `User`

#### Scenario: Unlinked shared email does not group

- **GIVEN** two `Person` records sharing an email string but not linked to a `User`
- **WHEN** the system groups identities
- **THEN** the records are not grouped until a link is established

### Requirement: Holder sees their linked persons across organizations

The system SHALL allow an account holder to view all of their linked `Person` records across organizations as a self-scoped read. This view MUST NOT be available to managers and MUST NOT expose one organization's data to another.

#### Scenario: Holder views their own persons across organizations

- **GIVEN** a `User` linked to persons in several organizations
- **WHEN** the holder views their account
- **THEN** the system lists their linked persons across those organizations

#### Scenario: Manager cannot view a person's other organizations

- **WHEN** a manager views a person
- **THEN** the system does not expose the person's `Person` records in other organizations

### Requirement: Global versus contextual data ownership

The system SHALL store authentication-account data on `User` (global) and identity data on `Person` (per organization). The system MUST NOT allow one organization to overwrite another organization's `Person` data or a shared `User`'s global data.

#### Scenario: Organization updates only its own Person data

- **GIVEN** a person exists in organizations O1 and O2
- **WHEN** a manager in O1 updates the person's contextual data
- **THEN** only the O1 `Person` record changes
- **AND** the O2 `Person` record is unaffected

#### Scenario: Global user data is not overwritten by an organization

- **GIVEN** a `User` already exists with global account data
- **WHEN** an organization incorporates that user
- **THEN** the system does not overwrite the user's global account data with organization-provided values

### Requirement: Identity operations do not create unit relationships

The system SHALL keep `UnitOwnership`, `UnitOccupancy`, and `StaffAssignment` as independent records. Creating a `User`, creating a `Person`, or linking a `User` to a `Person` MUST NOT create or alter any unit relationship.

#### Scenario: Creating an account does not create ownership

- **WHEN** a `User` account is created for a person
- **THEN** the system does not create a `UnitOwnership`

#### Scenario: Incorporation does not create occupancy

- **WHEN** a person is incorporated into an organization
- **THEN** the system does not create a `UnitOccupancy`
- **AND** existing unit relationships remain unchanged

#### Scenario: Linking a User does not alter residential relationships

- **GIVEN** a `Person` with existing active ownerships and occupancies
- **WHEN** a `User` is linked to that `Person`
- **THEN** the person's ownerships and occupancies are unchanged

### Requirement: Account provisioning is explicit

The system SHALL provision identity through explicit, single-responsibility services and MUST NOT auto-create a `Person`, membership, or role as an opaque side effect of account creation without identity resolution.

#### Scenario: No blind auto-provisioning

- **GIVEN** a person that already exists in the organization
- **WHEN** an account is created
- **THEN** the system resolves the existing `Person` before provisioning
- **AND** does not create a duplicate `Person`

### Requirement: Account may exist without an organization identity

The system SHALL allow a `User` to exist without any `Person`. Self-registration SHALL create a global account with no organization context, and MUST NOT auto-create a `Person`, membership, or role. A `Person` and membership are created only when the account is incorporated into an organization through an onboarding flow.

#### Scenario: Self-registration creates an empty account

- **WHEN** a person self-registers
- **THEN** the system creates a `User` with no `Person`, membership, or role
- **AND** the account has no organization context until incorporated

#### Scenario: Incorporation creates the organization identity

- **GIVEN** a self-registered `User` with no `Person`
- **WHEN** an organization incorporates the account
- **THEN** the system creates a `Person` and membership for that organization
- **AND** links them to the existing `User`

#### Scenario: Generating a visit auto-creates a visitor Person

- **GIVEN** a self-registered `User` with no `Person` in the host organization
- **WHEN** a visit is generated for that user in the organization
- **THEN** the system automatically creates a `Person` for that user in that organization as visitor
- **AND** does not require prior incorporation or membership

### Requirement: Database constraints for identity

The system SHALL enforce uniqueness of `Person.user_id` per organization for non-deleted records, uniqueness of the authentication email globally on `User`, and uniqueness of `document_number_digest` per organization and document type for active, non-deleted people.

#### Scenario: Duplicate document rejected within organization

- **GIVEN** an active person with a document in an organization
- **WHEN** another active person is created with the same document type and number in that organization
- **THEN** the system rejects the creation

