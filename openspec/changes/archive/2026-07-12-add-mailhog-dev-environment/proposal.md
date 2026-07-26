## Why

In development, `config.action_mailer.delivery_method` is set to `:resend`, which sends real emails through the Resend API even when developers are testing locally. This risks emails leaking to real inboxes during local testing (e.g. invitations, password resets, notifications) and makes it hard to inspect the exact content of an outgoing email without checking a third-party dashboard. MailHog provides a local SMTP server with a web UI to capture and inspect all outgoing mail during development, with no risk of external delivery.

## What Changes

- Add MailHog as a local development dependency (Docker container) to capture outgoing mail.
- Configure `config/environments/development.rb` to deliver mail via SMTP to the local MailHog instance instead of the `:resend` API, using `MAILHOG_SMTP_ADDRESS`/`MAILHOG_SMTP_PORT` environment variables (with `localhost`/`1025` defaults) so the host/port are never hardcoded.
- Add a `.env.example` file (none exists yet) documenting these variables for new developers, following the project's existing `PGHOST`/`PGPORT`-style env var convention.
- Document how to start MailHog and view captured emails (web UI) in the development setup docs.
- Existing mailer classes and views are unaffected; only the delivery transport changes for the `development` environment.

## Capabilities

### New Capabilities
- `mailhog-dev-environment`: Local email capture for the development environment via MailHog, including SMTP delivery configuration and developer-facing access to the MailHog web UI.

### Modified Capabilities
(none — no user-facing or spec-level behavior changes; this only affects the development environment's mail transport)

## Impact

- **Affected config**: `config/environments/development.rb` (`action_mailer.delivery_method`, `action_mailer.smtp_settings`); new `.env.example` at the repo root.
- **Affected tooling**: New Docker Compose service (or equivalent) for MailHog; developer setup documentation.
- **Not affected**: `production`/`staging` mailer configuration (`:resend` stays for those environments), mailer classes, mailer views, background job delivery logic.
- **Dependencies**: Requires Docker available locally to run the MailHog container (or a documented native binary alternative if Docker is not used for this project's dev environment).
- **Bounded context**: Development tooling / local environment configuration only — no production code paths, no tenant-scoped data, no authorization impact.
