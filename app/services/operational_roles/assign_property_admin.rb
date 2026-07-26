# frozen_string_literal: true

module OperationalRoles
  # Assigns the +property_admin+ operational role to a person on a property.
  #
  # Creates or reactivates a +StaffAssignment+ with +staff_type: StaffTypes::MANAGER+.
  # Grants capabilities from +Authorization::Capabilities::PROPERTY_ADMIN+ scoped
  # to +residential_property+ only. Requires a linked +User+ because the role
  # implies interactive system access.
  class AssignPropertyAdmin < BaseAssignment
    private

    def target_staff_type
      StaffTypes::MANAGER
    end

    def requires_system_access?
      true
    end
  end
end
