# frozen_string_literal: true

# Allowed +notifications.status+ values (string-backed).
module NotificationStatuses
  PENDING = "pending"
  SENT = "sent"
  FAILED = "failed"
  # No device token to deliver to — a terminal outcome (not an error), distinct
  # from PENDING. Notifications must never remain PENDING forever: the visit's
  # notification_status rollup waits for "no sibling is PENDING," so a resident
  # with no token would block that rollup indefinitely if left PENDING instead
  # of resolved to SKIPPED. See openspec/changes/add-fcm-push-notifications
  # design.md Decision 6/7.
  SKIPPED = "skipped"

  ALL = [ PENDING, SENT, FAILED, SKIPPED ].freeze
end
