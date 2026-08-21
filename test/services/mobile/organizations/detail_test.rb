# frozen_string_literal: true

require "test_helper"

module Mobile
  module Organizations
    class DetailTest < ActiveSupport::TestCase
      setup do
        @organization = organizations(:one)
        @user = create_user_for_organization(
          organization: @organization,
          email: "org-detail@example.com",
          role: AvailableRoles::CLIENT
        )
        @person = ActsAsTenant.with_tenant(@organization) { @user.person_for(@organization) }
      end

      test "returns organization branding and empty residential_properties when person has no relationships" do
        result = Detail.call(user: @user, organization_id: @organization.id)

        assert_equal @organization.name, result[:name]
        assert_nil result[:cover]
        assert_nil result[:logo]
        assert_equal [], result[:residential_properties]
      end

      test "returns unit with is_owner true and occupancy_type nil for owned-only unit" do
        unit = create_unit!(identifier: "DETAIL-OWNED")
        ActsAsTenant.with_tenant(@organization) do
          UnitOwnership.create!(
            organization: @organization, unit: unit, person: @person,
            ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
          )
        end

        result = Detail.call(user: @user, organization_id: @organization.id)

        assert_equal 1, result[:residential_properties].size
        property_entry = result[:residential_properties].first
        assert_equal 1, property_entry[:units].size
        entry = property_entry[:units].first
        assert_equal unit.id, entry[:id]
        assert_nil unit.code
        assert_nil entry[:code]
        assert entry[:display_name] == unit.display_name
        assert_equal unit.unit_type, entry[:unit_type]
        assert entry[:is_owner]
        assert_nil entry[:occupancy_type]
      end

      test "returns unit with is_owner false and occupancy_type set for occupied-only unit" do
        unit = create_unit!(identifier: "DETAIL-OCCUPIED")
        ActsAsTenant.with_tenant(@organization) do
          UnitOccupancy.create!(
            organization: @organization, unit: unit, person: @person,
            occupancy_type: OccupancyTypes::TENANT, status: OccupancyStatuses::ACTIVE, starts_at: Time.current
          )
        end

        result = Detail.call(user: @user, organization_id: @organization.id)

        entry = result[:residential_properties].first[:units].first
        refute entry[:is_owner]
        assert_equal OccupancyTypes::TENANT, entry[:occupancy_type]
      end

      test "returns a single entry when a unit is held via both ownership and occupancy" do
        unit = create_unit!(identifier: "DETAIL-SHARED")
        ActsAsTenant.with_tenant(@organization) do
          UnitOwnership.create!(
            organization: @organization, unit: unit, person: @person,
            ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
          )
          UnitOccupancy.create!(
            organization: @organization, unit: unit, person: @person,
            occupancy_type: OccupancyTypes::OWNER_RESIDENT, status: OccupancyStatuses::ACTIVE, starts_at: Time.current
          )
        end

        result = Detail.call(user: @user, organization_id: @organization.id)

        assert_equal 1, result[:residential_properties].size
        property_entry = result[:residential_properties].first
        assert_equal 1, property_entry[:units].size
        entry = property_entry[:units].first
        assert entry[:is_owner]
        assert_equal OccupancyTypes::OWNER_RESIDENT, entry[:occupancy_type]
      end

      test "excludes inactive ownership and occupancy" do
        unit = create_unit!(identifier: "DETAIL-INACTIVE")
        ActsAsTenant.with_tenant(@organization) do
          UnitOwnership.create!(
            organization: @organization, unit: unit, person: @person,
            ownership_percentage: 100, starts_at: Date.current, status: "inactive"
          )
          UnitOccupancy.create!(
            organization: @organization, unit: unit, person: @person,
            occupancy_type: OccupancyTypes::TENANT, status: OccupancyStatuses::INACTIVE, starts_at: Time.current
          )
        end

        result = Detail.call(user: @user, organization_id: @organization.id)

        assert_equal [], result[:residential_properties]
      end

      test "returns one entry per residential property with address fields and correctly partitioned units" do
        unit_a = create_unit!(identifier: "DETAIL-PROP-A")
        unit_b = create_unit!(identifier: "DETAIL-PROP-B")
        ActsAsTenant.with_tenant(@organization) do
          UnitOwnership.create!(
            organization: @organization, unit: unit_a, person: @person,
            ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
          )
          UnitOccupancy.create!(
            organization: @organization, unit: unit_b, person: @person,
            occupancy_type: OccupancyTypes::TENANT, status: OccupancyStatuses::ACTIVE, starts_at: Time.current
          )
        end

        result = Detail.call(user: @user, organization_id: @organization.id)

        assert_equal 2, result[:residential_properties].size
        property_a = result[:residential_properties].find { |p| p[:units].any? { |u| u[:id] == unit_a.id } }
        property_b = result[:residential_properties].find { |p| p[:units].any? { |u| u[:id] == unit_b.id } }

        assert_equal unit_a.residential_property.id, property_a[:id]
        assert_equal unit_a.residential_property.name, property_a[:name]
        assert_equal unit_a.residential_property.property_type, property_a[:property_type]
        assert_equal unit_a.residential_property.address_line, property_a[:address][:address_line]
        assert_equal unit_a.residential_property.city, property_a[:address][:city]
        assert_equal unit_a.residential_property.region, property_a[:address][:region]
        assert_equal 1, property_a[:units].size

        assert_equal unit_b.residential_property.id, property_b[:id]
        assert_equal 1, property_b[:units].size
      end

      test "omits a residential property with none of the user's units" do
        create_unit!(identifier: "DETAIL-PROP-EMPTY")

        result = Detail.call(user: @user, organization_id: @organization.id)

        assert_equal [], result[:residential_properties]
      end

      test "returns nil when user has no membership in the organization" do
        other_organization = organizations(:two)

        result = Detail.call(user: @user, organization_id: other_organization.id)

        assert_nil result
      end

      test "returns nil when membership is suspended" do
        @person.organization_membership.update!(status: OrganizationMembership::STATUS_SUSPENDED)

        result = Detail.call(user: @user, organization_id: @organization.id)

        assert_nil result
      end

      test "returns nil for a nonexistent organization id" do
        result = Detail.call(user: @user, organization_id: SecureRandom.uuid)

        assert_nil result
      end

      private

      def create_unit!(identifier:)
        property = ActsAsTenant.with_tenant(@organization) do
          ResidentialProperty.create!(
            organization: @organization,
            name: "Detail Property #{identifier}",
            property_type: PropertyTypes::BUILDING,
            status: "active",
            country: "Chile",
            timezone: "America/Santiago",
            address_line: "Av. Siempre Viva 742",
            city: "Santiago",
            region: "Metropolitana"
          )
        end
        ActsAsTenant.with_tenant(@organization) do
          Unit.create!(
            organization: @organization,
            residential_property: property,
            identifier: identifier,
            unit_type: UnitTypes::APARTMENT,
            status: UnitStatuses::AVAILABLE
          )
        end
      end
    end
  end
end
