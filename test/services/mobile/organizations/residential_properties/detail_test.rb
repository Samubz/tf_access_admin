# frozen_string_literal: true

require "test_helper"

module Mobile
  module Organizations
    module ResidentialProperties
      class DetailTest < ActiveSupport::TestCase
        setup do
          @organization = organizations(:one)
          @user = create_user_for_organization(
            organization: @organization,
            email: "rp-detail@example.com",
            role: AvailableRoles::CLIENT
          )
          @person = ActsAsTenant.with_tenant(@organization) { @user.person_for(@organization) }
          @property = create_property!(identifier: "RP-DETAIL", status: PropertyStatuses::ACTIVE)
        end

        test "returns property fields and unit with is_owner true for owned-only unit" do
          unit = create_unit!(property: @property, identifier: "RP-OWNED", status: UnitStatuses::AVAILABLE)
          own_unit!(unit)

          result = call

          assert_equal @property.id, result[:id]
          assert_equal @property.name, result[:name]
          assert_equal @property.property_type, result[:property_type]
          assert_equal @property.address_line, result[:address][:address_line]
          assert_equal @property.city, result[:address][:city]
          assert_equal @property.region, result[:address][:region]

          assert_equal 1, result[:units].size
          entry = result[:units].first
          assert_equal unit.id, entry[:id]
          assert entry[:is_owner]
          assert_nil entry[:occupancy_type]
        end

        test "returns unit with is_owner false and occupancy_type set for occupied-only unit" do
          unit = create_unit!(property: @property, identifier: "RP-OCCUPIED", status: UnitStatuses::OCCUPIED)
          occupy_unit!(unit)

          entry = call[:units].first

          refute entry[:is_owner]
          assert_equal OccupancyTypes::TENANT, entry[:occupancy_type]
        end

        test "returns a single entry when a unit is held via both ownership and occupancy" do
          unit = create_unit!(property: @property, identifier: "RP-SHARED", status: UnitStatuses::AVAILABLE)
          own_unit!(unit)
          occupy_unit!(unit, occupancy_type: OccupancyTypes::OWNER_RESIDENT)

          result = call

          assert_equal 1, result[:units].size
          entry = result[:units].first
          assert entry[:is_owner]
          assert_equal OccupancyTypes::OWNER_RESIDENT, entry[:occupancy_type]
        end

        test "excludes inactive ownership and occupancy" do
          unit = create_unit!(property: @property, identifier: "RP-INACTIVE-REL", status: UnitStatuses::AVAILABLE)
          own_unit!(unit, status: "inactive")
          occupy_unit!(unit, status: OccupancyStatuses::INACTIVE)

          assert_nil call
        end

        test "excludes a unit with ineligible status despite active ownership" do
          unit = create_unit!(property: @property, identifier: "RP-MAINTENANCE", status: UnitStatuses::MAINTENANCE)
          own_unit!(unit)

          assert_nil call
        end

        test "excludes units belonging to a different residential property" do
          other_property = create_property!(identifier: "RP-OTHER", status: PropertyStatuses::ACTIVE)
          unit = create_unit!(property: other_property, identifier: "RP-OTHER-UNIT", status: UnitStatuses::AVAILABLE)
          own_unit!(unit)

          assert_nil call
        end

        test "returns nil when user has no membership in the organization" do
          other_organization = organizations(:two)

          result = Detail.call(
            user: @user, organization_id: other_organization.id, residential_property_id: @property.id
          )

          assert_nil result
        end

        test "returns nil for a nonexistent organization id" do
          result = Detail.call(
            user: @user, organization_id: SecureRandom.uuid, residential_property_id: @property.id
          )

          assert_nil result
        end

        test "returns nil for a nonexistent residential property id" do
          result = Detail.call(
            user: @user, organization_id: @organization.id, residential_property_id: SecureRandom.uuid
          )

          assert_nil result
        end

        test "returns nil for a residential property belonging to a different organization" do
          other_organization = organizations(:two)
          other_property = ActsAsTenant.with_tenant(other_organization) do
            ResidentialProperty.create!(
              organization: other_organization,
              name: "Other Org Property",
              property_type: PropertyTypes::BUILDING,
              status: PropertyStatuses::ACTIVE,
              country: "Chile",
              timezone: "America/Santiago"
            )
          end

          result = Detail.call(
            user: @user, organization_id: @organization.id, residential_property_id: other_property.id
          )

          assert_nil result
        end

        test "returns nil when the residential property is not active" do
          [ PropertyStatuses::DRAFT, PropertyStatuses::CREATED, PropertyStatuses::CONFIGURED,
            PropertyStatuses::INACTIVE, PropertyStatuses::ARCHIVED ].each do |status|
            property = create_property!(identifier: "RP-STATUS-#{status}", status: status)
            unit = create_unit!(property: property, identifier: "RP-STATUS-#{status}-UNIT", status: UnitStatuses::AVAILABLE)
            own_unit!(unit)

            result = Detail.call(
              user: @user, organization_id: @organization.id, residential_property_id: property.id
            )

            assert_nil result, "expected nil for property status #{status}"
          end
        end

        test "returns nil when member has no eligible units in an otherwise-accessible property" do
          assert_nil call
        end

        private

        def call
          Detail.call(user: @user, organization_id: @organization.id, residential_property_id: @property.id)
        end

        def own_unit!(unit, status: UnitOwnership::STATUS_ACTIVE)
          ActsAsTenant.with_tenant(@organization) do
            UnitOwnership.create!(
              organization: @organization, unit: unit, person: @person,
              ownership_percentage: 100, starts_at: Date.current, status: status
            )
          end
        end

        def occupy_unit!(unit, occupancy_type: OccupancyTypes::TENANT, status: OccupancyStatuses::ACTIVE)
          ActsAsTenant.with_tenant(@organization) do
            UnitOccupancy.create!(
              organization: @organization, unit: unit, person: @person,
              occupancy_type: occupancy_type, status: status, starts_at: Time.current
            )
          end
        end

        def create_property!(identifier:, status:)
          ActsAsTenant.with_tenant(@organization) do
            ResidentialProperty.create!(
              organization: @organization,
              name: "Detail Property #{identifier}",
              property_type: PropertyTypes::BUILDING,
              status: status,
              country: "Chile",
              timezone: "America/Santiago",
              address_line: "Av. Siempre Viva 742",
              city: "Santiago",
              region: "Metropolitana"
            )
          end
        end

        def create_unit!(property:, identifier:, status:)
          ActsAsTenant.with_tenant(@organization) do
            Unit.create!(
              organization: @organization,
              residential_property: property,
              identifier: identifier,
              unit_type: UnitTypes::APARTMENT,
              status: status
            )
          end
        end
      end
    end
  end
end
