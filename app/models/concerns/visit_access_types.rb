# frozen_string_literal: true

# Allowed check-in +access_type+ metadata values.
module VisitAccessTypes
  PEDESTRIAN = "pedestrian"
  VEHICLE = "vehicle"
  DELIVERY = "delivery"
  OTHER = "other"

  ALL = [ PEDESTRIAN, VEHICLE, DELIVERY, OTHER ].freeze
end
