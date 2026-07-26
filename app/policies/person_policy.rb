# frozen_string_literal: true

class PersonPolicy < ApplicationPolicy
  include PersonPropertyRelationships

  def index?
    allowed?(:view_people) || any_accessible_property?(:view_people)
  end

  def show?
    return false unless same_organization?
    return true if viewing_own_person?
    return allowed?(:view_people) if resolver.profile.organization_wide?

    person_viewable_with_view_people?
  end

  def new?
    create?
  end

  def create?
    allowed?(:manage_people) || any_accessible_property?(:manage_people)
  end

  def invite?
    same_organization? && allowed?(:manage_people)
  end

  def edit?
    update?
  end

  def update?
    return false unless same_organization?
    return false if viewing_own_person?

    allowed?(:manage_people) || person_manageable_via_accessible_property?
  end

  def destroy?
    same_organization? && allowed?(:manage_people)
  end

  class Scope < ApplicationPolicy::Scope
    include PolicyScopeAuthorization
    include PersonPropertyRelationships

    def resolve
      return scope.none unless user.present?

      org = current_organization
      return scope.none unless org

      base = organization_scoped
      resolver = authorization_resolver
      return scope.none unless resolver

      if resolver.allowed?(:view_people)
        return base
      end

      property_ids = accessible_property_ids
      return scope.none if property_ids.empty?

      person_ids = people_ids_for_properties(property_ids, org)
      return scope.none if person_ids.empty?

      base.where(id: person_ids)
    end

    private

    def people_ids_for_properties(property_ids, organization)
      ownership_ids = UnitOwnership
        .joins(:unit)
        .where(organization_id: organization.id, status: UnitOwnership::STATUS_ACTIVE)
        .where(units: { residential_property_id: property_ids })
        .distinct
        .pluck(:person_id)

      occupancy_ids = UnitOccupancy
        .joins(:unit)
        .where(organization_id: organization.id, status: OccupancyStatuses::ACTIVE)
        .where(units: { residential_property_id: property_ids })
        .distinct
        .pluck(:person_id)

      staff_ids = StaffAssignment
        .where(organization_id: organization.id, status: "active", residential_property_id: property_ids)
        .distinct
        .pluck(:person_id)

      (ownership_ids + occupancy_ids + staff_ids).uniq
    end
  end

  private

  def person_viewable_with_view_people?
    viewable_property_ids = resolver.accessible_property_ids.select do |property_id|
      property_allowed?(:view_people, property_id: property_id)
    end
    return false if viewable_property_ids.empty?

    person_related_to_properties?(record, viewable_property_ids)
  end

  def person_manageable_via_accessible_property?
    manageable_property_ids = resolver.accessible_property_ids.select do |property_id|
      property_allowed?(:manage_people, property_id: property_id)
    end

    person_related_to_properties?(record, manageable_property_ids)
  end
end
