# frozen_string_literal: true

module Authorization
  module StaffRoleMapper
    PROPERTY_ADMIN = "property_admin"
    CONCIERGE = "concierge"
    CLEANING_STAFF = "cleaning_staff"
    INTERNAL_STAFF = "internal_staff"

    PROPERTY_SCOPED_ROLES = [
      PROPERTY_ADMIN,
      CONCIERGE,
      CLEANING_STAFF,
      INTERNAL_STAFF
    ].freeze

    STAFF_TYPE_TO_ROLE = {
      # Canonical persisted types (StaffTypes::ALL)
      StaffTypes::MANAGER => PROPERTY_ADMIN,
      StaffTypes::CONCIERGE => CONCIERGE,
      StaffTypes::SECURITY => CONCIERGE,
      StaffTypes::CLEANING => CLEANING_STAFF,
      StaffTypes::MAINTENANCE => INTERNAL_STAFF,
      StaffTypes::OTHER => INTERNAL_STAFF,
      # Legacy alias values that may exist in older data
      StaffTypes::PROPERTY_ADMIN => PROPERTY_ADMIN,
      StaffTypes::CLEANING_STAFF => CLEANING_STAFF,
      StaffTypes::INTERNAL_STAFF => INTERNAL_STAFF
    }.freeze

    module_function

    def operational_role_for(staff_type)
      STAFF_TYPE_TO_ROLE[staff_type]
    end

    def property_scoped_role?(role)
      PROPERTY_SCOPED_ROLES.include?(role)
    end
  end
end
