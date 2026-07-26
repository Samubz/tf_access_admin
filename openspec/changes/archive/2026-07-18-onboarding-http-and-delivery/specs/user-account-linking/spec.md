# User Account Linking

## ADDED Requirements

### Requirement: Confirmation gate is enforced at the session layer

The system SHALL block an unconfirmed `User` from using the application at authentication time (no unconfirmed grace period), even when the account is linked or incorporated.

#### Scenario: Unconfirmed account cannot authenticate into the app

- **GIVEN** a linked but unconfirmed `User`
- **WHEN** the user attempts to authenticate
- **THEN** the system denies access until confirmation

### Requirement: Password complexity policy

The system SHALL require every account password (invitation acceptance, admin creation, and password change) to be at least 8 characters and to contain at least one lowercase letter, one uppercase letter, one digit, and one special character.

#### Scenario: Weak password is rejected

- **WHEN** a holder sets a password that misses any required class or is under 8 characters
- **THEN** the system rejects it with a validation error

#### Scenario: Compliant password is accepted

- **WHEN** a holder sets a password with lower, upper, digit, special and length ≥ 8
- **THEN** the system accepts it
