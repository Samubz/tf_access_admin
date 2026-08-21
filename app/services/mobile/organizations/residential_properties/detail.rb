# frozen_string_literal: true

# A single residential property's identity/address plus the authenticated
# user's active, eligible-status units within it, for
# GET /api/v1/mobile/organization/:organization_id/residential_property/:id.
# Mobile sessions never set ActsAsTenant.current_tenant, so :organization_id
# must be validated against the user's own memberships (outside any tenant)
# before :residential_property_id is resolved inside that tenant.
module Mobile
  module Organizations
    module ResidentialProperties
      class Detail
        ELIGIBLE_UNIT_STATUSES = [ UnitStatuses::AVAILABLE, UnitStatuses::OCCUPIED ].freeze

        def self.call(user:, organization_id:, residential_property_id:)
          new(user: user, organization_id: organization_id, residential_property_id: residential_property_id).call
        end

        def initialize(user:, organization_id:, residential_property_id:)
          @user = user
          @organization_id = organization_id
          @residential_property_id = residential_property_id
        end

        def call
          organization = authorized_organization
          return nil if organization.blank?

          ActsAsTenant.with_tenant(organization) do
            property = ResidentialProperty.find_by(id: @residential_property_id)
            next nil if property.blank? || property.status != PropertyStatuses::ACTIVE

            person = @user.person_for(organization)
            units = eligible_units(person: person, property: property)
            next nil if units.blank?
            {
              id: property.id,
              name: property.name,
              property_type: property.property_type,
              address: {
                address_line: property.address_line,
                city: property.city,
                region: property.region
              },
              units: units
            }
          end
        end

        private

        def authorized_organization
          ActsAsTenant.without_tenant do
            organization = Organization.find_by(id: @organization_id)
            next nil if organization.blank?

            @user.member_of_tenant?(organization) ? organization : nil
          end
        end

        def eligible_units(person:, property:)
          owned_unit_ids = person.unit_ownerships.where(status: UnitOwnership::STATUS_ACTIVE)
            .distinct.pluck(:unit_id).to_set
          occupancy_type_by_unit_id = person.unit_occupancies
            .where(status: OccupancyStatuses::ACTIVE)
            .pluck(:unit_id, :occupancy_type).to_h

          unit_ids = owned_unit_ids | occupancy_type_by_unit_id.keys

          Unit.where(id: unit_ids, residential_property_id: property.id, status: ELIGIBLE_UNIT_STATUSES).map do |unit|
            {
              id: unit.id,
              code: unit.code,
              display_name: unit.display_name.presence || "#{t_unit_type(unit.unit_type)} #{unit.identifier}",
              unit_type: unit.unit_type,
              is_owner: owned_unit_ids.include?(unit.id),
              occupancy_type: occupancy_type_by_unit_id[unit.id]
            }
          end
        end

        def t_unit_type(unit_type)
          I18n.t("frontend.admin.units.unit_types.#{unit_type}", default: unit_type.to_s.humanize)
        end
      end
    end
  end
end
