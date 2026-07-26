# frozen_string_literal: true

# Derives contextual domain roles for a +Person+ from active relationships.
#
# Staff contextual roles (+concierge+, +property_admin+, +cleaning_staff+,
# +internal_staff+) are derived from active +StaffAssignment+ rows via
# +Authorization::StaffRoleMapper+, never stored as a direct attribute on
# +Person+.
module People
  class ContextualRoles
    OWNER = "owner"
    RESIDENT = "resident"
    VISITOR = "visitor"
    CONCIERGE = "concierge"
    PROPERTY_ADMIN = "property_admin"
    CLEANING_STAFF = "cleaning_staff"
    INTERNAL_STAFF = "internal_staff"
    SYSTEM_USER = "system_user"

    DOMAIN_ROLES = [
      OWNER,
      RESIDENT,
      VISITOR,
      CONCIERGE,
      PROPERTY_ADMIN,
      CLEANING_STAFF,
      INTERNAL_STAFF,
      SYSTEM_USER
    ].freeze

    STAFF_ROLES = [ CONCIERGE, PROPERTY_ADMIN, CLEANING_STAFF, INTERNAL_STAFF ].freeze

    def self.call(person)
      new(person).call
    end

    def self.batch_for(people)
      return {} if people.blank?

      person_ids = people.map(&:id)
      organization_id = people.first.organization_id

      owner_ids = UnitOwnership.where(
        organization_id: organization_id,
        person_id: person_ids,
        status: UnitOwnership::STATUS_ACTIVE
      ).distinct.pluck(:person_id).to_set

      resident_ids = UnitOccupancy.where(
        organization_id: organization_id,
        person_id: person_ids,
        status: OccupancyStatuses::ACTIVE
      ).distinct.pluck(:person_id).to_set

      visitor_ids = VisitorProfile.where(
        organization_id: organization_id,
        person_id: person_ids
      ).distinct.pluck(:person_id).to_set

      staff_roles_by_person = StaffAssignment
        .where(organization_id: organization_id, person_id: person_ids)
        .currently_active
        .pluck(:person_id, :staff_type)
        .each_with_object(Hash.new { |h, k| h[k] = [] }) do |(person_id, staff_type), hash|
          role = Authorization::StaffRoleMapper.operational_role_for(staff_type)
          hash[person_id] << role if role
        end

      people.each_with_object({}) do |person, roles_by_person|
        roles_by_person[person.id] = build_roles(
          owner: owner_ids.include?(person.id),
          resident: resident_ids.include?(person.id),
          visitor: visitor_ids.include?(person.id),
          system_user: person.user_id.present?,
          staff_roles: staff_roles_by_person[person.id]
        )
      end
    end

    def self.build_roles(owner:, resident:, visitor:, system_user:, staff_roles: [])
      [].tap do |roles|
        roles << OWNER if owner
        roles << RESIDENT if resident
        roles << VISITOR if visitor
        STAFF_ROLES.each { |r| roles << r if staff_roles.include?(r) }
        roles << SYSTEM_USER if system_user
      end
    end

    def initialize(person)
      @person = person
    end

    def call
      self.class.build_roles(
        owner: owner?,
        resident: resident?,
        visitor: visitor?,
        system_user: system_user?,
        staff_roles: operational_staff_roles
      )
    end

    private

    def owner?
      @person.unit_ownerships.where(status: UnitOwnership::STATUS_ACTIVE).exists?
    end

    def resident?
      @person.unit_occupancies.where(status: OccupancyStatuses::ACTIVE).exists?
    end

    def visitor?
      @person.visitor_profiles.exists?
    end

    def system_user?
      @person.user_id.present?
    end

    def operational_staff_roles
      @person.staff_assignments.currently_active.pluck(:staff_type).filter_map do |staff_type|
        Authorization::StaffRoleMapper.operational_role_for(staff_type)
      end.uniq
    end
  end
end
