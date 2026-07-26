# frozen_string_literal: true

module PersonPropertyRelationships
  extend ActiveSupport::Concern

  private

  def person_related_to_properties?(person, property_ids)
    return false if person.blank? || property_ids.blank?

    org = current_organization
    return false unless org

    person_has_staff_assignment_on?(person, property_ids, org) ||
      person_has_ownership_on?(person, property_ids, org) ||
      person_has_occupancy_on?(person, property_ids, org)
  end

  def person_has_staff_assignment_on?(person, property_ids, organization)
    Authorization::ActiveRelationships
      .active_staff_assignments_for(person, organization)
      .where(residential_property_id: property_ids)
      .exists?
  end

  def person_has_ownership_on?(person, property_ids, organization)
    Authorization::ActiveRelationships
      .active_ownerships_for(person, organization)
      .joins(:unit)
      .where(units: { residential_property_id: property_ids })
      .exists?
  end

  def person_has_occupancy_on?(person, property_ids, organization)
    Authorization::ActiveRelationships
      .active_occupancies_for(person, organization)
      .joins(:unit)
      .where(units: { residential_property_id: property_ids })
      .exists?
  end
end
