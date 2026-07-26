# frozen_string_literal: true

# Allowed +visits.visit_type+ values (string-backed).
module VisitTypes
  GUEST = "guest"
  DELIVERY = "delivery"
  SERVICE = "service"
  OTHER = "other"

  ALL = [ GUEST, DELIVERY, SERVICE, OTHER ].freeze
end
