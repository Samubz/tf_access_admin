# frozen_string_literal: true

# Visits scheduled for a unit on a given day, for
# GET /api/v1/mobile/residential_property/:id/unit/:unit_id/visitas.
# The route carries no :organization_id — the tenant is bootstrapped from an
# untrusted lookup of the residential property, then every subsequent read
# (property, unit, occupancy, visits) is re-resolved inside that tenant.
# Authorization is occupancy-only: an active UnitOwnership alone does not
# grant access.
module Mobile
  module ResidentialProperties
    module Units
      module Visits
        class Index
          ELIGIBLE_UNIT_STATUSES = [ UnitStatuses::AVAILABLE, UnitStatuses::OCCUPIED ].freeze

          def self.call(user:, residential_property_id:, unit_id:, day: nil)
            new(user: user, residential_property_id: residential_property_id, unit_id: unit_id, day: day).call
          end

          def initialize(user:, residential_property_id:, unit_id:, day: nil)
            @user = user
            @residential_property_id = residential_property_id
            @unit_id = unit_id
            @day = day
          end

          def call
            organization = bootstrap_organization
            return nil if organization.blank?

            ActsAsTenant.with_tenant(organization) do
              property = ResidentialProperty.find_by(id: @residential_property_id)
              next nil if property.blank? || property.status != PropertyStatuses::ACTIVE

              unit = Unit.find_by(id: @unit_id, residential_property_id: property.id)
              next nil if unit.blank? || !ELIGIBLE_UNIT_STATUSES.include?(unit.status)

              person = @user.person_for(organization)
              next nil if person.blank?

              occupancy = person.unit_occupancies.find_by(unit_id: unit.id, status: OccupancyStatuses::ACTIVE)
              next nil if occupancy.blank?

              date = parse_day
              next :invalid_day if date == :invalid_day

              visits_for(unit: unit, property: property, date: date)
            end
          end

          private

          def bootstrap_organization
            ActsAsTenant.without_tenant do
              ResidentialProperty.find_by(id: @residential_property_id)&.organization
            end
          end

          def parse_day
            return Date.iso8601(@day) if @day.present?

            :today
          rescue ArgumentError, TypeError
            :invalid_day
          end

          def visits_for(unit:, property:, date:)
            zone = ActiveSupport::TimeZone[property.timezone]
            date = zone.today if date == :today

            local_day = zone.local(date.year, date.month, date.day)
            range = local_day.beginning_of_day.utc..local_day.end_of_day.utc

            Visit.where(unit_id: unit.id, scheduled_at: range).order(:scheduled_at).map do |visit|
              {
                visitor_name: visit.visitor_person.display_name,
                checked_in_at: visit.checked_in_at,
                checked_out_at: visit.checked_out_at,
                status: visit.status
              }
            end
          end
        end
      end
    end
  end
end
