# frozen_string_literal: true

require "test_helper"

class UnitOccupancyPolicyTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization

    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Occupancy Policy Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
    @unit = Unit.create!(
      organization: @organization,
      residential_property: @property,
      identifier: "OCC-POL-101",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
    @person = Person.create!(
      organization: @organization,
      display_name: "Occupancy Policy Person",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @occupancy = UnitOccupancy.create!(
      organization: @organization,
      unit: @unit,
      person: @person,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: Time.current,
      status: "active"
    )

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "tenant-admin-occupancies-policy@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @non_admin = create_user_for_organization(
      organization: @organization,
      email: "non-admin-occupancies-policy@example.test",
      role: AvailableRoles::CLIENT
    )

    @super_admin = create_user_for_organization(
      organization: @organization,
      email: "super-admin-occupancies-policy@example.test",
      role: AvailableRoles::SUPER_ADMIN
    )

    @other_org_occupancy = ActsAsTenant.without_tenant do
      other_property = ResidentialProperty.create!(
        organization: @other_organization,
        name: "Other Org Occupancy Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      other_unit = Unit.create!(
        organization: @other_organization,
        residential_property: other_property,
        identifier: "OTH-OCC-101",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
      other_person = Person.create!(
        organization: @other_organization,
        display_name: "Other Org Occupant",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      UnitOccupancy.create!(
        organization: @other_organization,
        unit: other_unit,
        person: other_person,
        occupancy_type: OccupancyTypes::TENANT,
        starts_at: Time.current,
        status: "active"
      )
    end
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "tenant admin can create update and destroy occupancy in same organization" do
    policy = UnitOccupancyPolicy.new(@tenant_admin, @occupancy)

    assert policy.create?
    assert policy.update?
    assert policy.destroy?
  end

  test "tenant admin can authorize class-level occupancy mutations" do
    policy = UnitOccupancyPolicy.new(@tenant_admin, UnitOccupancy)

    assert policy.create?
    assert policy.update?
    assert policy.destroy?
  end

  test "non-admin user cannot create update or destroy occupancy" do
    policy = UnitOccupancyPolicy.new(@non_admin, @occupancy)

    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "non-admin user cannot authorize class-level occupancy mutations" do
    policy = UnitOccupancyPolicy.new(@non_admin, UnitOccupancy)

    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "tenant admin cannot manage occupancy from another organization" do
    policy = UnitOccupancyPolicy.new(@tenant_admin, @other_org_occupancy)

    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "super admin can manage occupancy in current tenant" do
    policy = UnitOccupancyPolicy.new(@super_admin, @occupancy)

    assert policy.create?
    assert policy.update?
    assert policy.destroy?
  end

  test "scope returns occupancies for current tenant when user is tenant admin" do
    resolved = UnitOccupancyPolicy::Scope.new(@tenant_admin, UnitOccupancy.all).resolve

    assert_includes resolved, @occupancy
    assert_not_includes resolved, @other_org_occupancy
  end

  test "scope returns none for non-admin users" do
    resolved = UnitOccupancyPolicy::Scope.new(@non_admin, UnitOccupancy.all).resolve

    assert_empty resolved
  end

  test "pundit resolves UnitOccupancyPolicy for UnitOccupancy class and records" do
    assert_equal UnitOccupancyPolicy, Pundit.policy!(@tenant_admin, UnitOccupancy).class
    assert_equal UnitOccupancyPolicy, Pundit.policy!(@tenant_admin, @occupancy).class
  end
end
