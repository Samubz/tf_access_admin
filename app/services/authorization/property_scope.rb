# frozen_string_literal: true

module Authorization
  class PropertyScope
    def initialize(resolver)
      @resolver = resolver
    end

    def accessible_property_ids
      ids = profile.accessible_property_ids
      ids.select { |property_id| organization_property_ids.include?(property_id) }
    end

    def managed_properties
      property_records_for(StaffRoleMapper::PROPERTY_ADMIN)
    end

    def concierge_properties
      property_records_for(StaffRoleMapper::CONCIERGE)
    end

    def staff_properties
      StaffRoleMapper::PROPERTY_SCOPED_ROLES.flat_map { |role| property_records_for(role) }.uniq
    end

    def owned_unit_properties
      properties_for_units(active_ownership_unit_ids)
    end

    def occupied_unit_properties
      properties_for_units(active_occupancy_unit_ids)
    end

    private

    attr_reader :resolver

    def profile
      resolver.profile
    end

    def organization
      resolver.organization
    end

    def organization_property_ids
      @organization_property_ids ||= ResidentialProperty.where(organization_id: organization.id).pluck(:id).to_set
    end

    def property_records_for(roles)
      role_list = Array(roles)
      property_ids = role_list.flat_map { |role| profile.property_ids_for_role(role) }.uniq
      scoped_property_ids(property_ids)
    end

    def scoped_property_ids(property_ids)
      property_ids.select { |property_id| organization_property_ids.include?(property_id) }
    end

    def properties_for_units(unit_ids)
      return [] if unit_ids.blank?

      Unit
        .where(id: unit_ids, organization_id: organization.id)
        .distinct
        .pluck(:residential_property_id)
        .select { |property_id| organization_property_ids.include?(property_id) }
    end

    def active_ownership_unit_ids
      person = resolver.user.person_for(organization)
      return [] unless person

      ActiveRelationships.active_ownerships_for(person, organization).pluck(:unit_id)
    end

    def active_occupancy_unit_ids
      person = resolver.user.person_for(organization)
      return [] unless person

      ActiveRelationships.active_occupancies_for(person, organization).pluck(:unit_id)
    end
  end
end
