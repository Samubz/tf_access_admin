# frozen_string_literal: true

module OperationalRoles
  # Assigns the +concierge+ operational role to a person on a property.
  #
  # Creates or reactivates a +StaffAssignment+ with +staff_type: StaffTypes::CONCIERGE+.
  # Grants visit access-control capabilities from +Authorization::Capabilities::CONCIERGE+
  # scoped to +residential_property+ only. No administrative capabilities are granted.
  # Requires a linked +User+ because the role implies interactive system access.
  class AssignConcierge < BaseAssignment
    private

    def target_staff_type
      StaffTypes::CONCIERGE
    end

    def requires_system_access?
      true
    end
  end
end
