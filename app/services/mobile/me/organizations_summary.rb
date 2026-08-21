# frozen_string_literal: true

# Summarizes the organizations a mobile client user belongs to, for
# GET /api/v1/mobile/me. Mobile sessions never set ActsAsTenant.current_tenant
# (see Api::V1::Mobile::Auth::SessionsController#create), so this reads
# across every tenant the user's Person records belong to.
module Mobile
  module Me
    class OrganizationsSummary
      def self.call(user)
        new(user).call
      end

      def initialize(user)
        @user = user
      end

      def call
        ActsAsTenant.without_tenant do
          people = @user.people
            .joins(:organization_membership)
            .merge(OrganizationMembership.active_or_invited)
            .includes(:organization)
            .order("organizations.name" => :asc)

          units_count_by_person_id = units_count_by_person_id(people)

          people.map do |person|
            {
              id: person.organization.id,
              name: person.organization.name,
              logo: person.organization.logo_path,
              units_count: units_count_by_person_id.fetch(person.id, 0)
            }
          end
        end
      end

      private

      def units_count_by_person_id(people)
        person_ids = people.map(&:id)
        return {} if person_ids.blank?

        owned = UnitOwnership.where(person_id: person_ids, status: UnitOwnership::STATUS_ACTIVE)
          .distinct.pluck(:person_id, :unit_id)
        occupied = UnitOccupancy.where(person_id: person_ids, status: OccupancyStatuses::ACTIVE)
          .distinct.pluck(:person_id, :unit_id)

        unit_ids_by_person_id = Hash.new { |h, k| h[k] = Set.new }
        (owned + occupied).each { |person_id, unit_id| unit_ids_by_person_id[person_id] << unit_id }

        unit_ids_by_person_id.transform_values(&:size)
      end
    end
  end
end
