## Context

`Notification` (`app/models/notification.rb`) already models a generic notification record — `channel` (`push`/`email`/`sms`/`in_app`/`webhook`/`other`), `notification_type` (`visit_request`/`visit_approved`/.../`other`), polymorphic `notifiable`, `recipient_person`, optional `residential_property`/`unit`, and delivery bookkeeping (`status`, `sent_at`, `attempts_count`, `last_error`). Nothing in the codebase creates or delivers a `Notification` today — it is pure data model with no producer or consumer.

`UnitOccupancy` already exposes `can_authorize_visits` and `UnitOccupancy.active_authorizers_for(unit)`, which is exactly "residents who can authorize entry for this unit." Per the clarified scope for this change, notification recipients are the visited unit's authorizers only (not every unit in the residential property) — reusing this scope directly.

There is no existing per-user device/push-token storage. `User` (Devise `database_authenticatable, recoverable, rememberable, validatable, confirmable, jwt_authenticatable`) is the authenticated resource for the mobile client (confirmed via `Api::V1::Private::*`, which already exists for the resident-facing visit registration API at `POST /api/v1/private/units/:unit_id/visits`). `Person belongs_to :user, optional: true`, and other models (e.g. `UnitOccupancy`) already `delegate :user, to: :person` — this change follows that same path in the other direction: `unit_occupancy.person.user.device_tokens`.

There is a local FCM-compatible simulator, PushHog, already running at `http://localhost:8090` (started independently of this repo, similar to how MailHog is started independently — see the `add-mailhog-dev-environment` change for the established `ENV.fetch("X", default)` + `.env.example` convention this design follows). PushHog documents two ingestion shapes; this design uses the modern Firebase HTTP v1 shape (`POST /v1/projects/{project_id}/messages:send`) since the legacy shape is deprecated by Google. PushHog does not validate the `Authorization` header, which is consistent with deferring real OAuth2 to a follow-up change.

`Visits::Create` (`app/services/visits/create.rb`) is the single creation path used by the admin `admin/visits/new` flow (`ServiceAuthorization#authorize_visit_action!`, wraps visit build + save + `RecordEvent` in a transaction). This is the one integration point for this change's trigger.

`User has_many :organization_memberships, through: :people` — a single `User` can be a resident/authorizer in more than one organization (e.g. owns or rents units in two different managed properties under two different orgs). Since `device_tokens` is owned by `User` (not scoped per-organization), one physical device receives push notifications for **every** organization that `User` is a resident-authorizer in. This is confirmed as the desired behavior (analogous to one phone receiving notifications from multiple unrelated apps) — not an oversight or a tenant-isolation gap, since each `Notification` row is still correctly organization-scoped; only the delivery *target* (one device) is shared across the user's organizations.

## Goals / Non-Goals

**Goals:**
- A `User` can register (and revoke) a single FCM device token via an authenticated private API endpoint, mirroring the existing `Api::V1::Private::*` pattern.
- `Fcm::Client` sends push notifications via HTTP POST to a configurable base URL (`FCM_BASE_URL`), defaulting to the real Firebase endpoint everywhere and overridden to PushHog (`http://localhost:8090`) in development via `.env`.
- When an admin creates a visit through `Visits::Create`, one `Notification` (`notification_type: "visit_request"`, `channel: "push"`) is created per active resident authorizer of the visited unit, and delivery is attempted for each of those residents' single registered device token.
- Delivery is asynchronous (Sidekiq job) and never blocks or fails visit creation.
- Delivery failures are recorded on the `Notification` row (`status`, `last_error`, `attempts_count`) and are visible for troubleshooting, not silently dropped.
- The visit itself tracks an aggregate `notification_status` (`pending`/`delivered`/`failed`/`no_recipients`) so an operator can see, at a glance, whether the residents who can authorize entry were actually reached — and can manually trigger a resend when delivery genuinely failed.

**Non-Goals:**
- Real Firebase OAuth2 / service-account authentication for staging/production FCM calls. `Fcm::Client` will send a configured static credential (if present) as an `Authorization` header, but generating that credential from a Google service account JSON is out of scope.
- Retrying failed deliveries automatically (e.g. exponential backoff, dead-letter handling) beyond what Sidekiq's default job retry behavior already provides — the *manual* operator resend (see Decision 7) is the only retry path this change builds.
- Any notification UI/inbox (read/unread list, in-app bell) — this change only produces and delivers the `Notification` row; consuming it in a resident-facing UI is a separate concern.
- Notifying residents of a unit other than the one the visit targets — scope is unit-level, not property-wide (explicitly decided over property-wide broadcast).
- Web push (browser) or APNs-direct delivery — FCM is the only transport, and its documented behavior already supports iOS via APNs under the hood, so no separate iOS path is built.
- Multiple simultaneous devices per resident — by design, a `User` has at most one registered device token at a time (see Decision 2); multi-device support is out of scope.
- Automatic session/login invalidation on a device when a new device registers — only the push-delivery target changes (the old device silently stops receiving pushes); this change does not touch Devise/JWT session logic.

## Decisions

1. **Recipient resolution reuses `UnitOccupancy.active_authorizers_for(unit)` — unit-scoped, not property-scoped.**
   The visited `Unit` is known from the `Visit` (`visit.unit`). `UnitOccupancy.active_authorizers_for(visit.unit)` already returns exactly the active, currently-in-validity-window occupancies with `can_authorize_visits: true`. No new query needed.
   - *Alternative considered*: querying all `active_authorizers` across every unit in `visit.unit.residential_property` — rejected because it would notify residents of unrelated units about a visit that has nothing to do with them, which is surprising and noisy at any property with more than a handful of units.

2. **New `device_tokens` table, owned by `User` (`has_one`, not `has_many`) — one device per user at a time.**
   ```ruby
   create_table :device_tokens, id: :uuid do |t|
     t.references :user, type: :uuid, null: false, foreign_key: true, index: { unique: true }
     t.string :token, null: false
     t.string :platform, null: false # DeviceTokens::Platforms::ALL = %w[ios android web]
     t.datetime :last_seen_at
     t.timestamps
   end
   ```
   Ownership is `User` (not `Person`) because the mobile client authenticates as a `User` via JWT (`devise-jwt`, already used by `Api::V1::Private::*`) — a `Person` can exist without ever having a `User` (e.g. a visitor-only or admin-imported person), so anchoring to `User` avoids a nullable/optional ownership chain at registration time. Reaching a resident's token for delivery goes `unit_occupancy.person.user.device_token` (`delegate :user, to: :person` already exists on `UnitOccupancy`).
   `user_id` is unique — a `User` has **at most one** device token at a time, by product decision: a resident is expected to use one device for the app; logging into a new device is expected to make the previous one stop receiving push (the user must log out of the old device to use a new one, from the product's perspective — no forced session invalidation is implemented, only the push target changes). Registration is a plain upsert: `DeviceToken.find_or_initialize_by(user: current_user).update!(token:, platform:, last_seen_at: Time.current)` — no conflict/reassignment logic is needed since there is nothing to conflict with; the `token` column itself carries no uniqueness constraint (a shared household device could legitimately produce the same physical FCM token for two different residents' rows, which is acceptable and out of scope to prevent).
   - *Alternative considered*: `has_many` with global token uniqueness and reassign-on-conflict logic (the original draft of this decision) — rejected after discussion: the single-device-per-user product decision makes multi-token storage and cross-user conflict handling unnecessary complexity for a case that isn't expected to happen in the normal flow.
   - *Alternative considered*: storing the token directly on `Person` — rejected since `Person` is a domain/business record (can represent a visitor with no login), whereas device tokens are strictly an authentication-session-adjacent concept that belongs with `User`.

3. **Device token registration endpoint mirrors the existing `Api::V1::Private::*` resident API pattern.**
   Add `Api::V1::Private::DeviceTokensController < Api::V1::Private::BaseController` (inherits `authenticate_user!` + tenant check) with `create` (upsert the current user's single token, replacing any existing one) and `destroy` (revoke, e.g. on logout — clears the current user's token row). Route: `POST /api/v1/private/device_token`, `DELETE /api/v1/private/device_token` (singular resource — a `User` has at most one, so no `:id` param is needed; the endpoint always acts on `current_user`'s own token).
   - *Alternative considered*: a public/unauthenticated registration endpoint — rejected; an unauthenticated device-token endpoint would let anyone register a token against an organization, defeating the purpose of targeted, tenant-scoped notifications.

4. **`Fcm::Client` is a thin HTTP wrapper using the Firebase HTTP v1 request shape, with base URL and project ID from config. It returns a result object and never raises on delivery failure.**
   ```ruby
   module Fcm
     class Client
       Result = Struct.new(:success?, :error_message, keyword_init: true)

       def initialize(
         base_url: ENV.fetch("FCM_BASE_URL", "https://fcm.googleapis.com"),
         project_id: ENV.fetch("FCM_PROJECT_ID", "development"),
         auth_token: Rails.application.credentials.dig(:fcm, :auth_token)
       )
         ...
       end

       def send_notification(token:, title:, body:, data: {})
         # POST {base_url}/v1/projects/{project_id}/messages:send
         # body: { message: { token:, notification: { title:, body: }, data: } }
         # Rescues connection errors and non-2xx responses internally;
         # ALWAYS returns a Result — never raises for a delivery failure.
         # (A raised exception here would abort DeliverPushNotificationJob
         # before it reaches the Notification/notification_status update in
         # Decision 7 — see that decision's note on required failure handling.)
       end
     end
   end
   ```
   `FCM_PROJECT_ID` defaults to a harmless placeholder (`"development"`) since PushHog does not validate it; a real project ID is only meaningful once real Firebase credentials exist (non-goal). This mirrors the MailHog change's `ENV.fetch("MAILHOG_SMTP_ADDRESS", "localhost")` pattern and belongs in `.env`/`.env.example`, not hardcoded.
   - *Alternative considered*: the legacy FCM HTTP API (`POST /fcm/send`, `Authorization: key=...`) — rejected since Google has deprecated it and PushHog itself documents the v1 shape as the primary/recommended one.
   - *Alternative considered*: a Firebase Admin SDK gem — rejected per PushHog's own documented limitation ("the official Firebase Admin SDKs... cannot be redirected" to a custom base URL without patching internals); a direct HTTP client is the only integration path that stays swappable between PushHog and real FCM.
   - *Alternative considered*: letting HTTP/FCM errors raise and rescuing them in the caller (`DeliverPushNotificationJob`) instead — functionally equivalent, but a `Result` return value was chosen so the "never raises for a delivery failure" contract is enforced at the client boundary itself, rather than relying on every caller remembering to rescue broadly.

   **`data` payload contract**: `{ type: "visit_request", visit_id: <uuid>, residential_property_name: <string>, unit_identifier: <string>, visitor_name: <string> }`. This is the minimum the mobile client needs to deep-link to the right visit and render a meaningful notification without an extra API round-trip.

5. **Notification-row creation is synchronous (local DB only); only per-resident delivery is a Sidekiq job. That job runs at most once per enqueue — Sidekiq's automatic retry is explicitly disabled.**
   `Visits::Create#call` gains a step after the transaction succeeds (not inside it, so a notification failure can never roll back a created visit): synchronously resolve `UnitOccupancy.active_authorizers_for(visit.unit)` and create one `Notification` per resident (`recipient_person`, `unit`, `residential_property`, `notifiable: visit`, `notification_type: NotificationTypes::VISIT_REQUEST`, `channel: NotificationChannels::PUSH`, `status: "pending"`). This is pure local DB work (no external I/O), so it does not need to be a background job itself — only the actual FCM HTTP call does. For each created `Notification`, enqueue one `DeliverPushNotificationJob.perform_async(notification_id)` — one job per resident (not per device, since a resident has at most one device token per Decision 2).

   `DeliverPushNotificationJob` sets `sidekiq_options retry: false` (Sidekiq jobs retry by default via `ApplicationJob`'s Sidekiq queue adapter, with no global `retry_on`/`discard_on` override in this codebase — that default must be explicitly turned off here). The job calls `Fcm::Client#send_notification`, which returns a `Result` rather than raising (Decision 4), so the job body never has an unhandled exception path: every execution — success, FCM-reported failure, or no-token no-op — reaches the `Notification`/`notification_status` update in Decision 7 exactly once. **The only retry mechanism for a failed delivery is the operator-triggered manual resend** (Decision 7) — this was an explicit product decision, not an oversight: automatic Sidekiq retries would silently keep attempting delivery in the background for up to ~3 weeks by default, racing with (or masking the need for) the manual resend, and the operator would have no visibility into "is this still retrying on its own."
   This replaces an earlier two-job-tier draft of this decision (a separate fan-out job plus per-token delivery jobs); with single-device-per-user (Decision 2) there is no longer a need to fan out per-token, and resolving recipients is cheap enough to not require a queue hop of its own.
   - *Alternative considered*: doing recipient resolution and delivery synchronously inside `Visits::Create` — rejected; an external HTTP call (even to a local simulator) must never be on the critical path of visit creation.
   - *Alternative considered*: a separate async fan-out job before per-resident delivery jobs — rejected as unnecessary indirection once device tokens are 1:1 with users; the recipient query is a fast local read, not worth its own queue round-trip.
   - *Alternative considered*: leaving Sidekiq's default automatic retry enabled — rejected; it directly conflicts with the product decision that only a visible, operator-triggered resend should retry delivery (see this decision's product-decision note above).

6. **A resident with no registered device token still gets a `Notification` row, resolved to a terminal `skipped` status (never left `pending`).**
   The `Notification` is the durable "this resident was owed a visit_request notice" record regardless of whether a device token exists yet. `DeliverPushNotificationJob` checks `person.user&.device_token`; if absent, it sets the `Notification`'s status to `skipped` (a fourth `Notification` status alongside `pending`/`sent`/`failed`) with no error recorded — it's an absence of a delivery target, not a failure.
   `skipped` must be a distinct terminal status, not a continuation of `pending`: the Decision 7 rollup waits for "no sibling `Notification` is still `pending`" before finalizing `visit.notification_status`. If a no-token resident's row stayed `pending` forever (as an earlier draft of this decision assumed), that rollup would never complete for any visit where at least one authorizer lacks a device token — a real bug, caught and fixed during implementation, not a product decision. `skipped` resolves this: it leaves `pending` immediately (exactly once, since each `Notification` gets exactly one `DeliverPushNotificationJob`), so the rollup always terminates.

7. **`Visit` gains an independent `notification_status` column, computed by the last `DeliverPushNotificationJob` to finish, driving an operator-facing manual resend action.**
   Added alongside (not merged into) the existing AASM `status` column, since notification delivery outcome is orthogonal to the visit's authorization lifecycle (`pending`/`authorized`/`checked_in`/...) — a visit can be `authorized` and still have `notification_status: "failed"` if the residents were never actually reached.
   ```ruby
   add_column :visits, :notification_status, :string, null: false, default: "pending"
   # Visit::NotificationStatuses::ALL = %w[pending delivered failed no_recipients]
   ```
   - `no_recipients`: either zero active authorizers exist for the unit (no `Notification` rows created at all), or `Notification` rows exist but none of those residents has a registered device token (zero actual FCM attempts were made). Tells the operator "nobody could have been reached — go tell the resident in person," distinct from a technical failure.
   - `failed`: at least one real FCM send attempt was made (a resident had a token) and **all** attempts failed. Tells the operator "we tried and it didn't go through — probably worth retrying."
   - `delivered`: at least one attempt succeeded (not "all" — per product decision, one successful delivery is enough to consider the visit's residents notified).
   - `pending`: default; deliveries still in flight.

   Because this project only uses open-source Sidekiq (no Batch API), the "have all attempts finished, and did any succeed" check is done by each `DeliverPushNotificationJob`, on completion, taking a row lock on the visit and re-evaluating its notifications as a group:
   ```ruby
   Visit.transaction do
     visit = Visit.lock.find(visit_id)
     visit_notifications = visit.notifications.where(notification_type: NotificationTypes::VISIT_REQUEST)
     next if visit_notifications.exists?(status: NotificationStatuses::PENDING) # other jobs still in flight

     visit.update!(notification_status:
       if visit_notifications.exists?(status: NotificationStatuses::SENT)
         Visit::NotificationStatuses::DELIVERED
       elsif visit_notifications.exists?(status: NotificationStatuses::FAILED)
         Visit::NotificationStatuses::FAILED
       else
         # every sibling resolved to SKIPPED (see Decision 6) — nobody had a token to attempt
         Visit::NotificationStatuses::NO_RECIPIENTS
       end)
   end
   ```
   This only works cleanly because `skipped` (Decision 6) is a distinct terminal status from `pending` — the "other jobs still in flight" check would never resolve if a no-token resident's row stayed `pending` forever. The `Visit.lock` (`SELECT ... FOR UPDATE`) ensures only one of the (potentially several, concurrently-finishing) per-resident jobs performs the final aggregate write, avoiding a race where two "last" jobs both see stale sibling state.

   **Manual resend** (operator-facing, admin-only): a new member route `POST /admin/visits/:id/resend_notification` (alongside the existing `authorize_visit`/`cancel` member actions), enabled **only when `notification_status == "failed"`** (not for `no_recipients` or `delivered` — a resend can't help "no_recipients" since the underlying problem is "no one to notify," not a delivery hiccup, and is explicitly out of scope per product decision). The resend action retries the **same original residents** from the visit's existing `Notification` rows (not a fresh re-resolution of current unit authorizers) — it resets those rows to `status: "pending"`, resets `visit.notification_status` to `"pending"`, and re-enqueues one `DeliverPushNotificationJob` per existing `Notification`.
   - *Alternative considered*: re-resolving current active authorizers on resend (in case unit occupancy changed since the original visit) — rejected per product decision: resend targets the same residents as the original attempt, keeping the retry semantically simple ("try reaching the same people again") rather than silently changing who gets notified between the original attempt and a retry.
   - *Alternative considered*: allowing resend for `no_recipients` too — rejected per product decision: `no_recipients` means there was no one/nothing to send to in the first place, so a resend against the same (empty or tokenless) recipient set would just reproduce `no_recipients` again; it is not a transient failure to retry.

   **Resend history is preserved via `audited`, not overwritten.** Resetting a `Notification` row's `status`/`last_error`/`sent_at` in place would silently discard what happened on the previous attempt (only `attempts_count` would hint that more than one try occurred). Per product decision, `Notification` gets `audited` (the same gem already used elsewhere in this codebase for ownership/occupancy/staff-role auditability — see `UnitOccupancy`), covering at least `status`, `last_error`, `sent_at`, `attempts_count`. Each resend's reset-to-`pending` and each delivery job's terminal update becomes its own audit entry, so an admin (or support engineer) can reconstruct the full timeline of every attempt for a given `Notification`, not just its current state.

## Risks / Trade-offs

- **[Risk] A resident who never registers a device token has their `Notification` permanently `skipped` with no path to redelivery for that specific visit.** → Mitigation: acceptable for this change (Decision 6); a follow-up could add a scheduled sweep re-attempting `skipped` notifications once a token is later registered, or surface "undelivered" counts in an admin view, but is out of scope now.
- **[Risk] `FCM_BASE_URL` misconfigured in a real (non-development) environment silently points at PushHog or vice versa.** → Mitigation: default value is the real Firebase endpoint (fail-safe direction — the risk is a *development* machine forgetting to override to PushHog, not a production machine accidentally hitting a local simulator); document the override clearly in `.env.example`, matching the MailHog precedent.
- **[Risk] No real Firebase authentication means any non-development environment that actually wires this up before the OAuth2 follow-up lands would send unauthenticated requests to `fcm.googleapis.com`, which will simply reject them (401/403).** → Mitigation: this is an explicit non-goal; the design fails loudly (FCM will reject unauthenticated calls) rather than silently, and `Notification.last_error` captures the rejection for visibility. Real production rollout is blocked on the follow-up OAuth2 work, not silently broken.
- **[Risk] Two `DeliverPushNotificationJob`s for the same visit finish at nearly the same time and race on the aggregate `notification_status` rollup.** → Mitigation: `Visit.lock` (`SELECT ... FOR UPDATE`) around the read-then-write in Decision 7 ensures only one job performs the final aggregate check-and-write at a time; the check itself is idempotent (recomputing the same aggregate twice is harmless), so the lock is purely to avoid a stale-read race, not to prevent duplicate work.
- **[Risk] A resident switching devices without the old device explicitly revoking its token has no functional impact beyond no longer receiving push** — this is by design (Decision 2), but could confuse a user who expects an old device to keep working. → Mitigation: acceptable trade-off per product decision; a follow-up could surface "this device is no longer receiving notifications" messaging client-side, out of scope here.
- **[Risk] Disabling Sidekiq's automatic retry (Decision 5) means a purely transient failure (e.g. a one-off network blip) will not self-heal — it requires the operator to notice `notification_status: "failed"` and click resend.** → Mitigation: accepted trade-off per explicit product decision (Decision 5); this was chosen deliberately over silent background retries so the operator always has visibility and control over when a retry happens, rather than not knowing whether a "failed" notification might still succeed on its own moments later.

## Migration Plan

- Add `device_tokens` migration (new table, FK to `users`, unique index on `user_id`).
- Add `visits.notification_status` migration (`string`, default `"pending"`) + `Visit::NotificationStatuses` concern.
- Add `audited` to `Notification` (covering `status`, `last_error`, `sent_at`, `attempts_count`) so resend history is preserved rather than overwritten.
- Add `Fcm::Client` (returns a `Result`, never raises on delivery failure), `DeliverPushNotificationJob` (`sidekiq_options retry: false`), the resend service (e.g. `Visits::ResendNotification`).
- Add `Api::V1::Private::DeviceTokensController` (singular-resource `create`/`destroy` on `current_user`'s own token) + routes.
- Update `Visits::Create` to synchronously create `Notification` rows and enqueue one `DeliverPushNotificationJob` per resident, post-transaction.
- Add the `resend_notification` member route/action to admin visits, gated on `notification_status == "failed"`.
- Add `FCM_BASE_URL`/`FCM_PROJECT_ID` to `.env.example` (PushHog defaults) and document real-FCM override in the README, mirroring the MailHog section.
- No data migration needed for existing `Notification` rows (table exists, unused); existing visits backfill `notification_status: "pending"` via the column default (harmless — no admin UI depends on it retroactively).
- Rollback: revert the `Visits::Create` hook (stop creating notifications/enqueueing), drop `device_tokens` table, drop `visits.notification_status` column, remove `audited` from `Notification`, remove the resend route; existing `Notification`/`notification_types`/`notification_channels` infrastructure is unaffected and safe to leave in place since it was already unused before this change.

## Open Questions

- ~~Whether `attempts_count > 0` (vs a dedicated boolean) is the cleanest signal...~~ Resolved during implementation: `Notification` gets a fourth status, `skipped` (Decision 6), used exactly for "no token to attempt." The Decision 7 rollup branches on `sent` / `failed` / (implicitly all `skipped`) directly, with no need to inspect `attempts_count` for this purpose.
- Push notification copy (title/body) i18n keys and exact locale strings — to be finalized during implementation under `admin.visits.notifications.*` or `api.notifications.*` namespace, following the project's i18n convention (`es`/`en`/`pt`).
- Whether `residential_property_name`/`unit_identifier` in the `data` payload (Decision 4) should be the raw model attributes (e.g. `unit.identifier`) or a display-formatted string (e.g. however `unit.display_name`/similar already formats it elsewhere in serializers) — a task-time detail, should reuse whatever existing formatting helper the codebase already has rather than inventing a new one.
