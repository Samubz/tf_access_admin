# frozen_string_literal: true

module Authorization
  module ActiveRelationships
    module_function

    # Returns active and currently-valid StaffAssignment rows for a person
    # within an explicit organization context. This is the single authoritative
    # query for operational property roles; the Resolver and GrantProfile MUST
    # use this method — never build ad-hoc status/date filters elsewhere.
    def active_staff_assignments_for(person, organization, at: Date.current)
      return StaffAssignment.none if person.blank? || organization.blank?

      StaffAssignment
        .where(organization_id: organization.id, person_id: person.id)
        .currently_active(at: at)
    end

    def active_ownerships_for(person, organization, at: Date.current)
      return UnitOwnership.none if person.blank? || organization.blank?

      UnitOwnership
        .where(organization_id: organization.id, person_id: person.id, status: UnitOwnership::STATUS_ACTIVE)
        .where("starts_at <= ?", at)
        .where("ends_at IS NULL OR ends_at >= ?", at)
    end

    def active_occupancies_for(person, organization, at: Time.zone.now)
      return UnitOccupancy.none if person.blank? || organization.blank?

      day_start = at.in_time_zone.beginning_of_day
      day_end = at.in_time_zone.end_of_day

      UnitOccupancy
        .where(organization_id: organization.id, person_id: person.id, status: OccupancyStatuses::ACTIVE)
        .where("starts_at <= ?", day_end)
        .where("ends_at IS NULL OR ends_at >= ?", day_start)
    end
  end
end
