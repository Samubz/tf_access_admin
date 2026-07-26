# frozen_string_literal: true

# Allowed +visits.notification_status+ values (string-backed).
#
# Independent of the AASM +status+ column (Visit::StateMachine) — reflects
# whether the visit's resident authorizers were reached by push, which is
# orthogonal to the visit's authorization lifecycle. See
# openspec/changes/add-fcm-push-notifications/design.md Decision 7.
module Visit::NotificationStatuses
  PENDING = "pending"
  DELIVERED = "delivered"
  FAILED = "failed"
  NO_RECIPIENTS = "no_recipients"

  ALL = [ PENDING, DELIVERED, FAILED, NO_RECIPIENTS ].freeze
end
