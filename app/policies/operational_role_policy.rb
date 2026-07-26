# frozen_string_literal: true

# Policy for managing operational roles and staff assignments.
# All actions require :manage_staff_assignments capability — held org-wide
# (tenant_admin) or on at least one accessible property (property_admin).
class OperationalRolePolicy < ApplicationPolicy
  def index?
    allowed?(:manage_staff_assignments) || any_accessible_property?(:manage_staff_assignments)
  end

  def show?
    index?
  end

  def create?
    index?
  end

  # record is a StaffAssignment — check capability scoped to its property.
  def destroy?
    return allowed?(:manage_staff_assignments) unless record.respond_to?(:residential_property_id)

    property_allowed?(:manage_staff_assignments, property_id: record.residential_property_id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      org = ActsAsTenant.current_tenant
      profile = Authorization::GrantProfile.build(user, org)
      if profile.organization_capabilities.include?(:manage_staff_assignments)
        scope.all
      else
        property_ids = profile.property_capabilities
          .select { |_, caps| caps.include?(:manage_staff_assignments) }
          .keys
        scope.where(residential_property_id: property_ids)
      end
    end
  end
end
