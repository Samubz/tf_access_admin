# frozen_string_literal: true

# Authorization for the residential-property catalog (improve-property-foundation §4).
#
# Capabilities:
#   * +manage_properties+ — organizational; create, archive, and org-wide update.
#   * +manage_property+   — property-scoped via active StaffAssignment only.
#
# Property-admin access is never derived from a global role; it always flows from
# an active, currently valid assignment on the target property.
class ResidentialPropertyPolicy < ApplicationPolicy
  def index?
    allowed?(:manage_properties) || resolver.accessible_property_ids.any?
  end

  def show?
    same_organization? && property_accessible?(record)
  end

  def new?
    create?
  end

  def create?
    allowed?(:manage_properties)
  end

  def edit?
    update?
  end

  def update?
    return false unless same_organization?

    allowed?(:manage_properties) || property_allowed?(:manage_property, property: record)
  end

  # Explicit non-destructive archive (§4.1). Organizational capability only (§4.4/§4.6).
  def archive?
    same_organization? && allowed?(:manage_properties)
  end

  # Controllers and legacy callers may still route through +destroy?+ until §5
  # replaces the destructive action with +archive+.
  def destroy?
    archive?
  end

  class Scope < ApplicationPolicy::Scope
    include PolicyScopeAuthorization

    def resolve
      return scope.none unless user.present?

      ids = accessible_property_ids
      return scope.none if ids.empty?

      organization_scoped.where(id: ids)
    end
  end
end
