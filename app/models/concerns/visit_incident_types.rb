# frozen_string_literal: true

# Allowed check-out +incident_type+ metadata values.
module VisitIncidentTypes
  NONE = "none"
  NOISE = "noise"
  DAMAGE = "damage"
  SECURITY = "security"
  OTHER = "other"

  ALL = [ NONE, NOISE, DAMAGE, SECURITY, OTHER ].freeze
end
