# frozen_string_literal: true

require "test_helper"

module Mobile
  module Me
    class OrganizationsSummaryTest < ActiveSupport::TestCase
      setup do
        @organization_one = organizations(:one)
        @organization_two = organizations(:two)
        @user = create_user_for_organization(
          organization: @organization_one,
          email: "orgs-summary@example.com",
          role: AvailableRoles::CLIENT
        )
      end

      test "returns empty array when user has no organization memberships" do
        user = ActsAsTenant.without_tenant { create_confirmed_user(email: "no-orgs@example.com") }

        assert_equal [], OrganizationsSummary.call(user)
      end

      test "returns organization with zero units_count when person has no ownerships or occupancies" do
        result = OrganizationsSummary.call(@user)

        assert_equal(
          [ { id: @organization_one.id, name: @organization_one.name, logo: nil, units_count: 0 } ],
          result
        )
      end

      test "counts distinct units across active ownership and occupancy without double-counting" do
        person = ActsAsTenant.with_tenant(@organization_one) { @user.person_for(@organization_one) }
        shared_unit = create_unit!(@organization_one, identifier: "SUMMARY-SHARED")
        owned_only_unit = create_unit!(@organization_one, identifier: "SUMMARY-OWNED")

        ActsAsTenant.with_tenant(@organization_one) do
          UnitOwnership.create!(
            organization: @organization_one, unit: shared_unit, person: person,
            ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
          )
          UnitOccupancy.create!(
            organization: @organization_one, unit: shared_unit, person: person,
            occupancy_type: OccupancyTypes::OWNER_RESIDENT, status: OccupancyStatuses::ACTIVE, starts_at: Time.current
          )
          UnitOwnership.create!(
            organization: @organization_one, unit: owned_only_unit, person: person,
            ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
          )
        end

        result = OrganizationsSummary.call(@user)

        assert_equal 2, result.first[:units_count]
      end

      test "excludes an inactive ownership from the count" do
        person = ActsAsTenant.with_tenant(@organization_one) { @user.person_for(@organization_one) }
        unit = create_unit!(@organization_one, identifier: "SUMMARY-INACTIVE")

        ActsAsTenant.with_tenant(@organization_one) do
          UnitOwnership.create!(
            organization: @organization_one, unit: unit, person: person,
            ownership_percentage: 100, starts_at: Date.current, status: "inactive"
          )
        end

        result = OrganizationsSummary.call(@user)

        assert_equal 0, result.first[:units_count]
      end

      test "excludes organization when membership is suspended" do
        person = ActsAsTenant.with_tenant(@organization_one) { @user.person_for(@organization_one) }
        person.organization_membership.update!(status: OrganizationMembership::STATUS_SUSPENDED)

        result = OrganizationsSummary.call(@user)

        assert_empty result
      end

      test "includes multiple organizations the user belongs to" do
        ActsAsTenant.with_tenant(@organization_two) do
          Accounts::ProvisionTenantIdentity.call(user: @user, organization: @organization_two)
        end

        result = OrganizationsSummary.call(@user)

        assert_equal [ @organization_one.id, @organization_two.id ].sort, result.map { |o| o[:id] }.sort
      end

      test "does not include a role key in the summary" do
        result = OrganizationsSummary.call(@user)

        refute result.first.key?(:role)
      end

      private

      def create_unit!(organization, identifier:)
        property = ResidentialProperty.create!(
          organization: organization,
          name: "Summary Property #{identifier}",
          property_type: PropertyTypes::BUILDING,
          status: "active",
          country: "Chile",
          timezone: "America/Santiago"
        )
        Unit.create!(
          organization: organization,
          residential_property: property,
          identifier: identifier,
          unit_type: UnitTypes::APARTMENT,
          status: UnitStatuses::AVAILABLE
        )
      end
    end
  end
end
