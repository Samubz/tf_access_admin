## ADDED Requirements

### Requirement: Local mail capture in development
The system SHALL deliver all outgoing mail in the `development` environment via SMTP to a local MailHog instance instead of a real email provider, so that no email sent during local development is delivered to a real recipient. The SMTP host and port SHALL be configurable via the `MAILHOG_SMTP_ADDRESS` and `MAILHOG_SMTP_PORT` environment variables, defaulting to `localhost` and `1025` respectively when unset.

#### Scenario: Mailer triggers in development with default configuration
- **GIVEN** the `development` environment is running with MailHog started on the default ports
- **AND** `MAILHOG_SMTP_ADDRESS`/`MAILHOG_SMTP_PORT` are not set
- **WHEN** any `ApplicationMailer` subclass delivers an email
- **THEN** the email is sent via SMTP to `localhost:1025`
- **AND** the email is not delivered to any real external recipient

#### Scenario: Mailer triggers in development with overridden SMTP settings
- **GIVEN** `MAILHOG_SMTP_ADDRESS` and `MAILHOG_SMTP_PORT` are set to a non-default host/port
- **AND** a MailHog instance is reachable at that host/port
- **WHEN** any `ApplicationMailer` subclass delivers an email
- **THEN** the email is sent via SMTP to the configured host/port instead of the default

#### Scenario: MailHog is not running
- **GIVEN** the `development` environment is running without MailHog reachable at the configured address/port
- **WHEN** a mailer attempts to deliver an email
- **THEN** the delivery raises a connection error
- **AND** the error is visible in the Rails development log instead of failing silently

### Requirement: Developer access to captured mail
The system SHALL provide a local web UI for developers to inspect the content, headers, and recipients of every email captured in development.

#### Scenario: Developer inspects a captured email
- **GIVEN** MailHog is running locally
- **AND** a mailer has delivered at least one email in the `development` environment
- **WHEN** a developer opens the MailHog web UI at `http://localhost:8025`
- **THEN** the developer sees the captured email listed with its subject, recipients, and rendered body

### Requirement: Isolated from other environments
The system SHALL NOT change mail delivery behavior for the `test`, `staging`, or `production` environments as a result of adding MailHog to development.

#### Scenario: Production delivery is unaffected
- **GIVEN** the `production` or `staging` environment configuration
- **WHEN** a mailer delivers an email
- **THEN** delivery continues to use the existing `:resend` provider configuration

#### Scenario: Test environment is unaffected
- **GIVEN** the `test` environment configuration
- **WHEN** a mailer delivers an email during a test run
- **THEN** delivery continues to use Rails' `:test` delivery method with no dependency on MailHog
