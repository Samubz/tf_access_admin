# frozen_string_literal: true

require "test_helper"

class UnitOwnershipPolicyTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization

    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Policy Test Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
    @unit = Unit.create!(
      organization: @organization,
      residential_property: @property,
      identifier: "POL-101",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
    @person = Person.create!(
      organization: @organization,
      display_name: "Policy Owner",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @ownership = UnitOwnership.create!(
      organization: @organization,
      unit: @unit,
      person: @person,
      ownership_percentage: 50,
      starts_at: Date.current,
      status: UnitOwnership::STATUS_ACTIVE
    )

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "tenant-admin-policy@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @non_admin = create_user_for_organization(
      organization: @organization,
      email: "non-admin-policy@example.test",
      role: AvailableRoles::CLIENT
    )

    @super_admin = create_user_for_organization(
      organization: @organization,
      email: "super-admin-policy@example.test",
      role: AvailableRoles::SUPER_ADMIN
    )

    @other_org_ownership = ActsAsTenant.without_tenant do
      other_property = ResidentialProperty.create!(
        organization: @other_organization,
        name: "Other Org Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      other_unit = Unit.create!(
        organization: @other_organization,
        residential_property: other_property,
        identifier: "OTH-101",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
      other_person = Person.create!(
        organization: @other_organization,
        display_name: "Other Org Owner",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      UnitOwnership.create!(
        organization: @other_organization,
        unit: other_unit,
        person: other_person,
        ownership_percentage: 100,
        starts_at: Date.current,
        status: UnitOwnership::STATUS_ACTIVE
      )
    end
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "tenant admin can create update and destroy ownership in same organization" do
    policy = UnitOwnershipPolicy.new(@tenant_admin, @ownership)

    assert policy.create?
    assert policy.update?
    assert policy.destroy?
  end

  test "tenant admin can authorize class-level ownership mutations" do
    policy = UnitOwnershipPolicy.new(@tenant_admin, UnitOwnership)

    assert policy.create?
    assert policy.update?
    assert policy.destroy?
  end

  test "non-admin user cannot create update or destroy ownership" do
    policy = UnitOwnershipPolicy.new(@non_admin, @ownership)

    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "non-admin user cannot authorize class-level ownership mutations" do
    policy = UnitOwnershipPolicy.new(@non_admin, UnitOwnership)

    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "tenant admin cannot manage ownership from another organization" do
    policy = UnitOwnershipPolicy.new(@tenant_admin, @other_org_ownership)

    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "super admin can manage ownership in current tenant" do
    policy = UnitOwnershipPolicy.new(@super_admin, @ownership)

    assert policy.create?
    assert policy.update?
    assert policy.destroy?
  end

  test "scope returns ownerships for current tenant when user is tenant admin" do
    resolved = UnitOwnershipPolicy::Scope.new(@tenant_admin, UnitOwnership.all).resolve

    assert_includes resolved, @ownership
    assert_not_includes resolved, @other_org_ownership
  end

  test "scope returns ownerships for current tenant when user is super admin" do
    resolved = UnitOwnershipPolicy::Scope.new(@super_admin, UnitOwnership.all).resolve

    assert_includes resolved, @ownership
    assert_not_includes resolved, @other_org_ownership
  end

  test "scope returns none for non-admin users" do
    resolved = UnitOwnershipPolicy::Scope.new(@non_admin, UnitOwnership.all).resolve

    assert_empty resolved
  end

  test "scope returns none when tenant is missing" do
    ActsAsTenant.current_tenant = nil

    resolved = UnitOwnershipPolicy::Scope.new(@tenant_admin, UnitOwnership.all).resolve

    assert_empty resolved
  end

  test "pundit resolves UnitOwnershipPolicy for UnitOwnership class and records" do
    assert_equal UnitOwnershipPolicy, Pundit.policy!(@tenant_admin, UnitOwnership).class
    assert_equal UnitOwnershipPolicy, Pundit.policy!(@tenant_admin, @ownership).class
  end
end
