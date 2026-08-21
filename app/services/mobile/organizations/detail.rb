# frozen_string_literal: true

# Organization branding + the authenticated user's active units within it, for
# GET /api/v1/mobile/organization/:id. Mobile sessions never set
# ActsAsTenant.current_tenant (see Api::V1::Mobile::Auth::SessionsController#create),
# so :id must be validated against the user's own memberships (outside any
# tenant) before any tenant-scoped read runs.
module Mobile
  module Organizations
    class Detail
      def self.call(user:, organization_id:)
        new(user: user, organization_id: organization_id).call
      end

      def initialize(user:, organization_id:)
        @user = user
        @organization_id = organization_id
      end

      def call
        organization = authorized_organization
        return nil if organization.blank?

        ActsAsTenant.with_tenant(organization) do
          person = @user.person_for(organization)

          {
            name: organization.name,
            cover: organization.cover_path,
            logo: organization.logo_path,
            residential_properties: residential_properties_for(person)
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

      def residential_properties_for(person)
        owned_unit_ids = person.unit_ownerships.where(status: UnitOwnership::STATUS_ACTIVE)
          .distinct.pluck(:unit_id).to_set
        occupancy_type_by_unit_id = person.unit_occupancies
          .where(status: OccupancyStatuses::ACTIVE)
          .pluck(:unit_id, :occupancy_type).to_h

        unit_ids = owned_unit_ids | occupancy_type_by_unit_id.keys

        units_by_property = Unit.where(id: unit_ids).includes(:residential_property)
          .group_by(&:residential_property)

        units_by_property.map do |property, units|
          {
            id: property.id,
            name: property.name,
            property_type: property.property_type,
            address: {
              address_line: property.address_line,
              city: property.city,
              region: property.region
            },
            units: units.map do |unit|
              {
                id: unit.id,
                code: unit.code,
                display_name: unit.display_name,
                unit_type: unit.unit_type,
                is_owner: owned_unit_ids.include?(unit.id),
                occupancy_type: occupancy_type_by_unit_id[unit.id]
              }
            end
          }
        end
      end
    end
  end
end
