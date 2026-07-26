# frozen_string_literal: true

module OperationalRoles
  module RoleDefinitions
    ROLES = [
      {
        key: "property_admin",
        scope: "property",
        staff_types: [ StaffTypes::MANAGER ],
        capabilities: Authorization::Capabilities::PROPERTY_ADMIN
      },
      {
        key: "concierge",
        scope: "property",
        staff_types: [ StaffTypes::CONCIERGE, StaffTypes::SECURITY ],
        capabilities: Authorization::Capabilities::CONCIERGE
      },
      {
        key: "cleaning_staff",
        scope: "property",
        staff_types: [ StaffTypes::CLEANING ],
        capabilities: Authorization::Capabilities::CLEANING_STAFF
      },
      {
        key: "internal_staff",
        scope: "property",
        staff_types: [ StaffTypes::MAINTENANCE, StaffTypes::OTHER ],
        capabilities: Authorization::Capabilities::INTERNAL_STAFF
      }
    ].freeze

    ORG_ROLES = [
      {
        key: "tenant_admin",
        scope: "organization",
        staff_types: [],
        org_role: AvailableRoles::TENANT_ADMIN,
        capabilities: Authorization::Capabilities::ORGANIZATION_ADMIN
      },
      {
        key: "content_manager",
        scope: "organization",
        staff_types: [],
        org_role: AvailableRoles::CONTENT_MANAGER,
        capabilities: Authorization::Capabilities::CONTENT_MANAGER
      }
    ].freeze

    module_function

    def all
      ROLES
    end

    def assignable
      ROLES
    end

    def find(key)
      all_for_matrix.find { |r| r[:key] == key.to_s }
    end

    def all_for_matrix
      ORG_ROLES + ROLES
    end
  end
end
