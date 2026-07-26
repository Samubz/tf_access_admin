# frozen_string_literal: true

module OperationalRoles
  # Assigns a +cleaning_staff+ or +internal_staff+ operational role to a person on a property.
  #
  # Accepts an explicit +staff_type+ from the non-manager, non-concierge values:
  # +StaffTypes::CLEANING+, +StaffTypes::MAINTENANCE+, or +StaffTypes::OTHER+.
  # Maps to +cleaning_staff+ or +internal_staff+ via +Authorization::StaffRoleMapper+.
  # No administrative or access-control capabilities are granted by default.
  # Does not require a linked +User+ — internal staff may not have system access.
  class AssignInternalStaff < BaseAssignment
    ALLOWED_STAFF_TYPES = [
      StaffTypes::CLEANING,
      StaffTypes::MAINTENANCE,
      StaffTypes::OTHER
    ].freeze

    def initialize(actor:, person:, organization:, residential_property:, staff_type:)
      super(actor: actor, person: person, organization: organization, residential_property: residential_property)
      @staff_type = staff_type
    end

    private

    attr_reader :staff_type

    def target_staff_type
      staff_type
    end

    def requires_system_access?
      false
    end

    def validate
      errors = super
      unless ALLOWED_STAFF_TYPES.include?(staff_type)
        errors << "staff_type must be one of: #{ALLOWED_STAFF_TYPES.join(', ')}"
      end
      errors
    end
  end
end
