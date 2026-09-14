# frozen_string_literal: true

module Api
  # Resolves the role exposed by the mobile API for a user within an organization.
  # Organizational roles win; any other member is a resident (owner/occupant).
  module RoleResolver
    RESIDENT = "resident"

    module_function

    def call(user, organization)
      return AvailableRoles::SUPER_ADMIN if user.super_admin?

      tenant_role = ActsAsTenant.with_tenant(organization) { user.tenant_role }
      return tenant_role if tenant_role.in?(AvailableRoles::TENANT_ROLE_PRIORITY)

      RESIDENT
    end
  end
end
