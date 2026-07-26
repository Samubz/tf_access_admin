## Why

Residents who can authorize entry for a unit (`UnitOccupancy#can_authorize_visits`) currently have no way to know a visit was created for their unit until they check the admin/resident app manually. The project already models a generic `Notification` record (`channel: "push"`, `notification_type: "visit_request"`) but nothing creates or delivers it. Adding Firebase Cloud Messaging (FCM) as the push transport, with an environment-swappable base URL, lets us close this loop starting with the highest-value trigger: an operator creating a visit in `admin/visits/new`.

## What Changes

- Add a `device_tokens` table and model, owned by `User` (the Devise/JWT-authenticated resource), to store one or more FCM registration tokens per device.
- Add an authenticated API endpoint for a mobile client to register/refresh/revoke its device token.
- Add an `Fcm::Client` service that POSTs to the Firebase HTTP v1 message shape (`{"message": {"token", "notification", "data"}}`), with the base URL configurable via `FCM_BASE_URL` (defaults to the real `https://fcm.googleapis.com` endpoint everywhere except development, where it points at the local PushHog simulator on `http://localhost:8090`).
- Add a background job that delivers a `Notification` (channel `push`) through `Fcm::Client` and updates its `status`/`sent_at`/`attempts_count`/`last_error`.
- Hook `Visits::Create` so that, after a visit is successfully created, the system creates one `Notification` (`notification_type: "visit_request"`, `notifiable: visit`) per active resident authorizer of the visited unit (`UnitOccupancy.active_authorizers_for(unit)`), and enqueues delivery for each of that resident's registered device tokens.
- **Non-goal**: real Firebase OAuth2 service-account authentication for staging/production. `Fcm::Client` sends an `Authorization` header if a token/key is configured via credentials, but generating that token from a Firebase service account is out of scope for this change and is left as a documented follow-up.

## Capabilities

### New Capabilities
- `fcm-push-notifications`: Device token registration per `User`, an environment-configurable FCM HTTP client, and delivery of `push`-channel `Notification` records with status tracking.

### Modified Capabilities
- `visit-management`: Creating a visit now triggers push notifications to the visited unit's active resident authorizers.

## Impact

- **New tables**: `device_tokens` (`user_id`, `token`, `platform`, timestamps).
- **New models/services**: `DeviceToken`, `Fcm::Client`, `Notifications::CreateForVisit` (or similar), a delivery job (e.g. `DeliverPushNotificationJob`).
- **Affected code**: `app/services/visits/create.rb` (post-create hook), `app/models/notification.rb` (first real usage), `app/models/concerns/notification_channels.rb` / `notification_types.rb` (already have `push` / `visit_request`, no change needed there).
- **New config**: `FCM_BASE_URL` env var (default real FCM endpoint; `.env`/`.env.example` set to PushHog's `http://localhost:8090` for local development), following the same `ENV.fetch`-with-default pattern established for MailHog (`MAILHOG_SMTP_ADDRESS`/`PORT`).
- **New routes**: an authenticated endpoint for device token registration (exact path decided in design).
- **Bounded context**: Visits (trigger point), Unit Occupancies (recipient resolution via `can_authorize_visits`), Notifications (delivery record), Users (device token ownership), Authentication (device token endpoint requires an authenticated `User`).
- **Tenant isolation**: `Notification` is already `acts_as_tenant :organization` and validates same-tenant associations; the new `device_tokens` table has no direct organization column but is only ever reached through `person.user` where `person` is already tenant-scoped — the delivery job must resolve tokens through the tenant-scoped `UnitOccupancy`/`Person` chain, never by querying `DeviceToken` directly across tenants.
- **Authorization**: no new Pundit policy for device token registration (a `User` may only register/revoke tokens for themselves); visit creation authorization is unchanged (`Visits::Create` already calls `authorize_visit_action!`), notification creation is a side effect with no separate authorization check.
- **Dependencies**: assumes PushHog is running locally per the (separate, already-merged) `add-mailhog-dev-environment`-style dev-tooling convention; no dependency on another in-progress OpenSpec change.
