# frozen_string_literal: true

module Authorization
  class GrantProfile
    attr_reader :user, :organization, :organization_capabilities, :property_capabilities, :unit_capabilities

    def self.build(user, organization)
      new(user, organization).tap(&:load!)
    end

    def initialize(user, organization)
      @user = user
      @organization = organization
      @organization_capabilities = Set.new
      @property_capabilities = {}
      @unit_capabilities = {}
      @unit_property_ids = {}
      @organization_wide = false
      @loaded = false
    end

    def load!
      return self if @loaded

      apply_organization_roles
      apply_staff_assignments
      apply_ownerships
      apply_occupancies

      @loaded = true
      self
    end

    def organization_wide?
      @organization_wide
    end

    def accessible_property_ids
      return organization_property_ids if organization_wide?

      property_ids = property_capabilities.keys
      property_ids.concat(@unit_property_ids.values)
      property_ids.uniq
    end

    def member_of_organization?
      user.super_admin? || user.member_of_tenant?(organization)
    end

    def property_ids_for_role(role)
      case role
      when StaffRoleMapper::PROPERTY_ADMIN
        staff_property_ids_for(StaffRoleMapper::PROPERTY_ADMIN)
      when StaffRoleMapper::CONCIERGE
        staff_property_ids_for(StaffRoleMapper::CONCIERGE)
      when StaffRoleMapper::CLEANING_STAFF, StaffRoleMapper::INTERNAL_STAFF
        staff_property_ids_for(role)
      else
        []
      end
    end

    private

    def apply_organization_roles
      return unless member_of_organization?

      if user.super_admin?
        grant_organization_capabilities(Capabilities::ORGANIZATION_ADMIN)
        grant_organization_capabilities([ Capabilities::RESOLVE_IDENTITY_CONFLICTS ])
        @organization_wide = true
      elsif tenant_admin?
        grant_organization_capabilities(Capabilities::ORGANIZATION_ADMIN)
        @organization_wide = true
      elsif content_manager?
        grant_organization_capabilities(Capabilities::CONTENT_MANAGER)
        @organization_wide = true
      end
    end

    def apply_staff_assignments
      person = person_in_organization
      return unless person

      ActiveRelationships.active_staff_assignments_for(person, organization).find_each do |assignment|
        operational_role = StaffRoleMapper.operational_role_for(assignment.staff_type)
        next unless operational_role

        capabilities = Capabilities::ROLE_CAPABILITY_MAP.fetch(operational_role.to_sym, [])
        grant_property_capabilities(assignment.residential_property_id, capabilities)
      end
    end

    def apply_ownerships
      person = person_in_organization
      return unless person

      ActiveRelationships.active_ownerships_for(person, organization).includes(:unit).find_each do |ownership|
        grant_unit_capabilities(ownership.unit_id, ownership.unit.residential_property_id, Capabilities::OWNER)
      end
    end

    def apply_occupancies
      person = person_in_organization
      return unless person

      ActiveRelationships.active_occupancies_for(person, organization).includes(:unit).find_each do |occupancy|
        capabilities = Capabilities::RESIDENT.dup
        capabilities << Capabilities::RESIDENT_AUTHORIZE_VISITS if occupancy.can_authorize_visits?

        grant_unit_capabilities(occupancy.unit_id, occupancy.unit.residential_property_id, capabilities)
      end
    end

    def grant_organization_capabilities(capabilities)
      capabilities.each { |capability| organization_capabilities << capability }
    end

    def grant_property_capabilities(property_id, capabilities)
      set = (@property_capabilities[property_id] ||= Set.new)
      capabilities.each { |capability| set << capability }
    end

    def grant_unit_capabilities(unit_id, property_id, capabilities)
      @unit_property_ids[unit_id] = property_id
      set = (@unit_capabilities[unit_id] ||= Set.new)
      capabilities.each { |capability| set << capability }
    end

    def staff_property_ids_for(role)
      person = person_in_organization
      return [] unless person

      ActiveRelationships.active_staff_assignments_for(person, organization).filter_map do |assignment|
        next unless StaffRoleMapper.operational_role_for(assignment.staff_type) == role

        assignment.residential_property_id
      end.uniq
    end

    def organization_property_ids
      ResidentialProperty.where(organization_id: organization.id).pluck(:id)
    end

    def person_in_organization
      @person_in_organization ||= user.person_for(organization)
    end

    def tenant_admin?
      person = person_in_organization
      person.present? && person.has_role?(AvailableRoles::TENANT_ADMIN, organization)
    end

    def content_manager?
      person = person_in_organization
      person.present? && person.has_role?(AvailableRoles::CONTENT_MANAGER, organization)
    end
  end
end
