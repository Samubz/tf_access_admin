## Context

The `development` environment currently sets `config.action_mailer.delivery_method = :resend` (`config/environments/development.rb:34`), which sends real emails through the Resend API. There is no local mail-capture tool in this project's development setup, and no `docker-compose.yml` exists yet — the project runs natively via `Procfile.dev` (`bin/rails s`, `bin/vite dev`, `bundle exec sidekiq`), with Postgres/Redis expected to be available locally (see `config/database.yml`).

MailHog is a well-known local SMTP server + web UI for catching outgoing mail in development, commonly run as a single Docker container exposing an SMTP port (1025) and a web UI port (8025).

## Goals / Non-Goals

**Goals:**
- Outgoing mail in `development` is captured locally and never delivered to real inboxes.
- Developers can inspect the exact rendered content (HTML/text) and headers of any mail sent during local development via a web UI.
- Setup requires minimal new tooling and fits the project's existing dev workflow (`Procfile.dev` / `bin/setup` style).
- `production` and `staging` mailer delivery (`:resend`) remain unchanged.

**Non-Goals:**
- No changes to mailer classes, mailer views, or i18n content of emails.
- No change to how mail is delivered in `staging`/`production`.
- Not adding MailHog to CI or test environments (`test` env already uses `:test` delivery method via Rails defaults, which does not send mail).
- Not building a native (non-Docker) install path as the primary method; Docker is assumed available since the project already ships a `Dockerfile`.

## Decisions

1. **Run MailHog via Docker Compose, not a native binary.**
   Add a `docker-compose.yml` at the repo root with a single `mailhog` service (`image: mailhog/mailhog`), exposing `1025:1025` (SMTP) and `8025:8025` (web UI). This avoids requiring developers to install and manage a separate binary/service and keeps parity with how a Dockerized dependency would normally be introduced in this codebase (a `Dockerfile` already exists for the app image itself).
   - *Alternative considered*: Homebrew (`brew install mailhog`) — rejected as primary path because it's macOS-only and the team may use other OSes; Docker is cross-platform and Docker is already a project dependency.

2. **Switch `development` mail delivery to SMTP pointed at MailHog, configured via environment variables.**
   In `config/environments/development.rb`, replace `config.action_mailer.delivery_method = :resend` with `config.action_mailer.delivery_method = :smtp` and add:
   ```ruby
   config.action_mailer.smtp_settings = {
     address: ENV.fetch("MAILHOG_SMTP_ADDRESS", "localhost"),
     port: ENV.fetch("MAILHOG_SMTP_PORT", 1025)
   }
   ```
   This mirrors the project's existing `ENV.fetch("PGHOST", "localhost")` / `ENV.fetch("PGPORT", 5432)` convention in `config/database.yml`: a short, tool-specific variable name with a sensible default, so the app boots correctly with zero `.env` configuration but remains overridable when a developer's MailHog runs on different ports or a different host.
   MailHog requires no authentication or TLS for local SMTP, so no credentials are needed. `config.action_mailer.raise_delivery_errors` should be left enabled (or explicitly set to `true`) so a missing MailHog container surfaces clearly instead of silently swallowing mail.
   - *Alternative considered*: Generic `SMTP_ADDRESS`/`SMTP_PORT` names — rejected in favor of `MAILHOG_*` to make the purpose of these variables unambiguous (this SMTP config is specifically for the local MailHog capture tool, not a general-purpose SMTP relay that could later be reused for something else).
   - *Alternative considered*: `letter_opener` gem (opens emails in the browser without SMTP) — rejected because it doesn't exercise the actual SMTP delivery path or let teammates/QA inspect mail from a shared always-on container; MailHog's web UI is closer to a real inbox and works the same way regardless of who triggers the email.

3. **Add `MAILHOG_SMTP_ADDRESS`/`MAILHOG_SMTP_PORT` to `.env.example`, not to a committed `.env`.**
   This project's `.env` is gitignored (`.gitignore:11` — `/.env*`) and holds real local secrets per developer; there is currently no `.env.example` documenting expected variables. Introduce `.env.example` with:
   ```
   MAILHOG_SMTP_ADDRESS=localhost
   MAILHOG_SMTP_PORT=1025
   ```
   Since `config/environments/development.rb` falls back to these same values via `ENV.fetch`, no developer is required to add anything to their local `.env` to get a working setup — `.env.example` exists purely as living documentation of the override, and to seed a new developer's `.env` when they copy it.

4. **Document, don't automate, MailHog startup.**
   Add a short section to the README (or a dedicated `docs/development.md` if one exists) explaining: `docker compose up -d mailhog`, then visit `http://localhost:8025` to view captured mail. Do not wire MailHog startup into `Procfile.dev` automatically, since not all contributors may have Docker running at all times and `bin/rails s` should not hard-depend on it.

## Risks / Trade-offs

- **[Risk] Developer forgets to start the MailHog container, mail delivery fails locally.** → Mitigation: keep `raise_delivery_errors` on in development so failures are visible immediately instead of failing silently; document the startup command clearly.
- **[Risk] Port conflicts (1025/8025) with other local tooling.** → Mitigation: ports are only bound when the compose service is explicitly started by the developer; `MAILHOG_SMTP_ADDRESS`/`MAILHOG_SMTP_PORT` env vars let a developer point the app at a MailHog instance on different ports without editing code.
- **[Risk] Divergence between dev (`:smtp`/MailHog) and prod (`:resend`) delivery paths could mask provider-specific issues (e.g. Resend-specific headers/behavior).** → Mitigation: this is an accepted trade-off — the goal is safe local iteration, not full delivery-path parity; provider-specific behavior should still be verified in staging before release.

## Migration Plan

- Add `docker-compose.yml` with the `mailhog` service.
- Update `config/environments/development.rb` mailer settings.
- Update developer-facing docs with startup/access instructions.
- No data migration, no impact on `staging`/`production` config or deployed behavior.
- Rollback: revert the config change to `:resend` and remove the compose service; no persisted state to clean up (MailHog stores captured mail in-memory only, per its default configuration).
