# frozen_string_literal: true

# Authorization for units (improve-units-foundation §5).
#
# Every action evaluates +view_units+ / +manage_units+ against the unit's
# residential property context (§5.1). Organization-wide tenant admins retain
# org access (§5.5); property admins and concierge require an active, valid
# +StaffAssignment+ (§5.6–§5.8, §5.10). Cross-property and cross-organization
# access is denied (§5.11). Owners retain minimal read via +view_own_unit_context+.
# No global property role is introduced (§5.13).
class UnitPolicy < ApplicationPolicy
  def index?
    accessible_view_units?
  end

  def show?
    view_with_context?(require_operable: false) || view_own_unit?
  end

  def new?
    create?
  end

  def create?
    return false if record_residential_property.nil?

    manage_with_context?(require_operable: true)
  end

  def edit?
    update?
  end

  def update?
    manage_with_context?(require_operable: true)
  end

  def move?
    manage_with_context?(require_operable: true)
  end

  def archive?
    manage_with_context?(require_operable: true)
  end

  def restore?
    manage_with_context?(require_operable: true)
  end

  def soft_delete?
    manage_with_context?(require_operable: true)
  end

  # Ordinary admin flows use lifecycle services; technical soft delete is explicit.
  def destroy?
    soft_delete?
  end

  class Scope < ApplicationPolicy::Scope
    include PolicyScopeAuthorization

    # §5.4/§5.11: organization-scoped units limited to properties with read
    # capability plus the actor's own unit context.
    def resolve
      return scope.none unless user.present?

      property_ids = viewable_property_ids
      unit_ids = own_unit_ids
      return scope.none if property_ids.empty? && unit_ids.empty?

      base = organization_scoped
      relation = nil

      if property_ids.any?
        relation = base.where(residential_property_id: property_ids)
      end
      if unit_ids.any?
        scoped_units = base.where(id: unit_ids)
        relation = relation ? relation.or(scoped_units) : scoped_units
      end

      relation || scope.none
    end

    private

    def viewable_property_ids
      resolver = authorization_resolver
      return organization_property_ids(resolver) if resolver&.profile&.organization_wide?

      resolver.accessible_property_ids.select do |property_id|
        property_allowed?(:view_units, property_id: property_id) ||
          property_allowed?(:manage_units, property_id: property_id)
      end
    end

    def own_unit_ids
      authorization_resolver&.profile&.unit_capabilities&.keys || []
    end

    def organization_property_ids(resolver)
      org = current_organization
      return [] unless org

      caps = resolver.profile.organization_capabilities
      return ResidentialProperty.where(organization_id: org.id).pluck(:id) if
        caps.include?(Authorization::Capabilities::VIEW_UNITS) ||
        caps.include?(Authorization::Capabilities::MANAGE_UNITS)

      []
    end

    def property_allowed?(capability, property_id:)
      org = current_organization
      return false unless org && user

      property = ResidentialProperty.find_by(id: property_id, organization_id: org.id)
      return false unless property

      Authorization::Resolver.new(
        user: user,
        organization: org,
        property: property,
        profile: authorization_resolver.profile
      ).allowed?(capability)
    end
  end

  private

  def view_with_context?(require_operable:)
    property = record_residential_property
    return accessible_view_units? if property.nil?

    return false unless property_in_current_organization?(property)
    return false if require_operable && !property_operable?(property)

    view_units_for?(property)
  end

  def manage_with_context?(require_operable:)
    property = record_residential_property
    return accessible_manage_units? if property.nil?

    return false unless property_in_current_organization?(property)
    return false if require_operable && !property_operable?(property)

    manage_units_for?(property)
  end

  def view_units_for?(property)
    allowed?(:view_units) || allowed?(:manage_units) ||
      property_allowed?(:view_units, property: property) ||
      property_allowed?(:manage_units, property: property)
  end

  def manage_units_for?(property)
    allowed?(:manage_units) || property_allowed?(:manage_units, property: property)
  end

  def accessible_view_units?
    allowed?(:view_units) || allowed?(:manage_units) ||
      any_accessible_property?(:view_units) || any_accessible_property?(:manage_units)
  end

  def accessible_manage_units?
    allowed?(:manage_units) || any_accessible_property?(:manage_units)
  end

  def view_own_unit?
    return false unless same_organization?
    return false unless record.is_a?(Unit)

    allowed?(:view_own_unit_context)
  end

  def property_in_current_organization?(property)
    return false unless user.present?
    return true if user.super_admin?

    org = current_organization
    org.present? && property.organization_id == org.id
  end

  include PropertyOperable
end
