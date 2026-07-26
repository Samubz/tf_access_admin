# frozen_string_literal: true

# Authorization for structural property sections (improve-property-sections §6).
#
# Every action evaluates +manage_sections+ with the section's property context
# (§6.1): organization-wide for a tenant admin (§6.3) and per-property for a
# property admin whose +StaffAssignment+ is active and currently valid (§6.4/§6.5,
# enforced by +Authorization::Resolver+). Cross-organization and cross-property
# access is denied here and excluded from the scope (§6.6). Ordinary mutations are
# additionally denied under an archived (non-operable) property (§6.7). No global
# section role is introduced (§6.9).
class PropertySectionPolicy < ApplicationPolicy
  def index?
    accessible_manage_sections?
  end

  def show?
    manage_with_context?(require_operable: false)
  end

  def new?
    create?
  end

  def create?
    manage_with_context?(require_operable: true)
  end

  def edit?
    update?
  end

  def update?
    manage_with_context?(require_operable: true)
  end

  # §6.8: parent/position changes go through their own mutation action.
  def move?
    manage_with_context?(require_operable: true)
  end

  # §6.8: archiving is an explicit, authorized lifecycle action and, like other
  # mutations, is denied under an archived property (§6.7).
  def archive?
    manage_with_context?(require_operable: true)
  end

  # Destructive deletion is never allowed through the ordinary administrative
  # flow — archive is the only supported retirement operation, even for a tenant
  # admin (improve-property-sections §"Delete vs archive strategy"). There is no
  # admin route that invokes +destroy+; this explicit denial is defense in depth.
  def destroy?
    false
  end

  class Scope < ApplicationPolicy::Scope
    include PolicyScopeAuthorization

    # §6.2/§6.6: only sections within the actor's organization and accessible
    # properties; everything else is excluded.
    def resolve
      return scope.none unless user.present?

      scoped_to_accessible_properties
    end
  end

  private

  # Resolves +manage_sections+ against the record's property context (§6.1). When
  # no concrete property is available (class-level authorization) it falls back to
  # the organization-wide / any-accessible-property check used by listings.
  def manage_with_context?(require_operable:)
    property = record_residential_property
    return accessible_manage_sections? if property.nil?

    return false unless property_in_current_organization?(property)
    return false if require_operable && !property_operable?(property)

    manage_sections_for?(property)
  end

  def manage_sections_for?(property)
    allowed?(:manage_sections) || property_allowed?(:manage_sections, property: property)
  end

  def accessible_manage_sections?
    any_accessible_property?(:manage_sections) || allowed?(:manage_sections)
  end

  def property_in_current_organization?(property)
    return false unless user.present?
    return true if user.super_admin?

    org = current_organization
    org.present? && property.organization_id == org.id
  end

  include PropertyOperable
end
