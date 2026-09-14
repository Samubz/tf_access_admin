# frozen_string_literal: true

# Allowed +notifications.notification_type+ values (string-backed).
module NotificationTypes
  VISIT_REQUEST   = "visit_request"
  VISIT_APPROVED  = "visit_approved"
  VISIT_REJECTED  = "visit_rejected"
  VISIT_INVITATION = "visit_invitation"
  ANNOUNCEMENT    = "announcement"
  PARCEL          = "parcel"
  INCIDENT        = "incident"
  RESERVATION     = "reservation"
  LEASE           = "lease"
  SYSTEM          = "system"
  OTHER           = "other"

  ALL = [
    VISIT_REQUEST,
    VISIT_APPROVED,
    VISIT_REJECTED,
    VISIT_INVITATION,
    ANNOUNCEMENT,
    PARCEL,
    INCIDENT,
    RESERVATION,
    LEASE,
    SYSTEM,
    OTHER
  ].freeze
end
