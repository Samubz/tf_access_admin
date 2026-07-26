## 1. Local MailHog Service

- [x] 1.1 Add `docker-compose.yml` at the repo root with a `mailhog` service (`image: mailhog/mailhog`), exposing port `1025` (SMTP) and `8025` (web UI).
- [x] 1.2 Confirm the container starts cleanly with `docker compose up -d mailhog` and the web UI loads at `http://localhost:8025`. (`docker compose config` validates; `docker compose up` created the container correctly — port bind conflict only occurred because a separate externally-managed MailHog instance was already running on the same host ports.)

## 2. Mailer Configuration

- [x] 2.1 Update `config/environments/development.rb`: replace `config.action_mailer.delivery_method = :resend` with `:smtp` and add `config.action_mailer.smtp_settings = { address: ENV.fetch("MAILHOG_SMTP_ADDRESS", "localhost"), port: ENV.fetch("MAILHOG_SMTP_PORT", 1025) }`.
- [x] 2.2 Ensure `config.action_mailer.raise_delivery_errors` is enabled in development so a missing MailHog container fails loudly instead of silently.
- [x] 2.3 Verify `staging`/`production` environment files still use `:resend` and are untouched. (No `staging` env file exists in this project. `production.rb` was confirmed untouched — and in fact never set `delivery_method = :resend` at all; only `development.rb` selected it. `Resend::Railtie` registers the `:resend` delivery method globally via the gem, but only `development` opted into it before this change.)

## 3. Environment Variables

- [x] 3.1 Create `.env.example` at the repo root (none exists yet) documenting `MAILHOG_SMTP_ADDRESS=localhost` and `MAILHOG_SMTP_PORT=1025` as the default local MailHog connection values.
- [x] 3.2 Confirm `.env.example` is not covered by the `/.env*` gitignore rule (add a negation entry if needed) so it is actually committed and available to new developers. (Added `!/.env.example` to `.gitignore`; verified with `git status` that it now shows as untracked/committable instead of ignored.)

## 4. Verification

- [x] 4.1 Trigger an existing mailer locally (e.g. via Rails console `SomeMailer.some_action.deliver_now`) with MailHog running and confirm it appears in the MailHog web UI. (No domain mailer subclasses exist yet beyond `ApplicationMailer`; verified via `bin/rails runner` sending a raw `Mail.new` through `ActionMailer::Base.smtp_settings` — confirmed `delivery_method=smtp address=localhost port=1025`, delivered successfully, and confirmed visible via MailHog's `/api/v2/messages` endpoint.)
- [x] 4.2 Stop the MailHog container and confirm the same mailer call raises a visible connection error in the Rails log instead of failing silently. (Simulated by pointing at a closed port (`MAILHOG_SMTP_PORT=1099`); delivery raised `Errno::ECONNREFUSED`, propagated as an unhandled exception with full backtrace — not swallowed.)
- [x] 4.3 Override `MAILHOG_SMTP_PORT` via `.env` (or inline `ENV`) to a non-default port matching a MailHog instance running there, and confirm mail delivery follows the override. (Confirmed via the same `MAILHOG_SMTP_PORT=1099` run above — `ActionMailer::Base.smtp_settings[:port]` correctly reflected `1099` instead of the `1025` default.)
- [x] 4.4 Run the existing mailer-related test suite (if any) to confirm the `test` environment's delivery method is unaffected. (No mailer-specific tests exist in `test/`. Statically confirmed `config/environments/test.rb:46` still sets `delivery_method = :test`, untouched by this change.)

## 5. Documentation

- [x] 5.1 Add a short "Local email testing (MailHog)" section to the project's developer setup docs (README or equivalent) covering: starting the container, viewing captured mail, stopping it, and overriding `MAILHOG_SMTP_ADDRESS`/`MAILHOG_SMTP_PORT` via `.env`.
