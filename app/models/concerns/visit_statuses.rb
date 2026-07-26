# frozen_string_literal: true

# Allowed +visits.status+ values (string-backed).
module VisitStatuses
  PENDING = "pending"
  AUTHORIZED = "authorized"
  CHECKED_IN = "checked_in"
  CHECKED_OUT = "checked_out"
  CANCELLED = "cancelled"

  # Prepared for post-MVP flows; no UI/services in the MVP change.
  REJECTED = "rejected"
  EXPIRED = "expired"

  MVP = [
    PENDING,
    AUTHORIZED,
    CHECKED_IN,
    CHECKED_OUT,
    CANCELLED
  ].freeze

  OPERATIONAL = [
    AUTHORIZED,
    CHECKED_IN,
    CHECKED_OUT
  ].freeze

  ALL = (MVP + [ REJECTED, EXPIRED ]).freeze
end
