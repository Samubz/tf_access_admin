# fcm-push-notifications

## ADDED Requirements

### Requirement: Expo Push transport is selected by token format

The system SHALL deliver push notifications through the Expo Push Service when the device token starts with `ExponentPushToken[`, and through FCM otherwise. The Expo base URL SHALL be configurable through `EXPO_PUSH_BASE_URL` (default `https://exp.host`) and an optional access token SHALL be read from credentials. Both transports SHALL expose the same result contract and MUST NOT raise.

#### Scenario: Expo token routes to Expo

- **GIVEN** a device token `ExponentPushToken[abc]`
- **WHEN** a push notification is delivered
- **THEN** the request is sent to `{EXPO_PUSH_BASE_URL}/--/api/v2/push/send`
- **AND** FCM is not called

#### Scenario: FCM token routes to FCM

- **GIVEN** a device token that does not start with `ExponentPushToken[`
- **WHEN** a push notification is delivered
- **THEN** the request is sent to FCM as before

#### Scenario: Transport failure is recorded, not raised

- **WHEN** the Expo service is unreachable
- **THEN** the notification is marked `failed` with the error message
- **AND** the job completes without exception

### Requirement: Unregistered device tokens are invalidated

When a transport reports that the device is no longer registered, the system SHALL mark the notification `failed` and delete the user's device token so no further attempts target it.

#### Scenario: DeviceNotRegistered removes the token

- **GIVEN** a user with device token T
- **WHEN** Expo responds with error `DeviceNotRegistered` for T
- **THEN** the notification is `failed`
- **AND** the user's device token no longer exists

### Requirement: Visit invitation push payload

The system SHALL support notification type `visit_invitation`, addressed to the visitor person, whose payload carries `data: { type: "visit_invitation", visit_id, residential_property_name, unit_identifier, scheduled_at }` and a localized title and body.

#### Scenario: Payload deep-links to the invitation

- **WHEN** a `visit_invitation` notification is delivered
- **THEN** the payload data includes the `visit_id` and `type: "visit_invitation"`
- **AND** the title and body use the recipient user's language
