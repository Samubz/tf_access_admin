# frozen_string_literal: true

require "test_helper"

class ApplicationPolicyTest < ActiveSupport::TestCase
  class TestPolicy < ApplicationPolicy
    def expose_record_residential_property
      record_residential_property
    end

    def expose_record_unit
      record_unit
    end
  end

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property = create_property(@organization, "Application Policy Property")
    @other_property = create_property(@organization, "Application Policy Property B")
    @section = PropertySection.create!(
      organization: @organization,
      residential_property: @property,
      name: "Tower A",
      section_type: SectionTypes::TOWER
    )
    @unit = create_unit(@property, "APP-POL-101")
    @person = Person.create!(
      organization: @organization,
      display_name: "Application Policy Person",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @ownership = UnitOwnership.create!(
      organization: @organization,
      unit: @unit,
      person: @person,
      ownership_percentage: 100,
      starts_at: Date.current,
      status: UnitOwnership::STATUS_ACTIVE
    )
    @occupancy = UnitOccupancy.create!(
      organization: @organization,
      unit: @unit,
      person: @person,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: Time.zone.now,
      status: OccupancyStatuses::ACTIVE
    )

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "tenant-admin-app-policy@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @property_admin = create_staff_user(
      email: "property-admin-app-policy@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )

    @other_org_property = ActsAsTenant.with_tenant(@other_organization) do
      create_property(@other_organization, "Other Org Application Policy Property")
    end

    @other_org_person = ActsAsTenant.with_tenant(@other_organization) do
      Person.create!(
        organization: @other_organization,
        display_name: "Other Org Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
    end
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "resolver delegates to Authorization::Resolver with record context" do
    policy = TestPolicy.new(@property_admin, @unit)
    resolver = policy.resolver

    assert_instance_of Authorization::Resolver, resolver
    assert_equal @property_admin, resolver.user
    assert_equal @organization, resolver.organization
    assert_equal @property, resolver.property
    assert_equal @unit, resolver.unit
    assert_equal @unit, resolver.record
  end

  test "resolver uses Current memoization when user and organization match" do
    Current.user = @tenant_admin
    Current.organization = @organization

    policy = TestPolicy.new(@tenant_admin, @property)
    resolver = policy.resolver

    assert_same Current.authorization_grant_profile, policy.resolver.profile
    assert_equal resolver.profile.object_id, Current.authorization_grant_profile.object_id
  end

  test "allowed? delegates to resolver" do
    policy = TestPolicy.new(@property_admin, @unit)

    assert policy.allowed?(:manage_units)
    refute policy.allowed?(:manage_users)
  end

  test "property_accessible? returns true for accessible property" do
    policy = TestPolicy.new(@property_admin, @unit)

    assert policy.property_accessible?(@property)
  end

  test "property_accessible? returns false for inaccessible property" do
    policy = TestPolicy.new(@property_admin, @unit)

    refute policy.property_accessible?(@other_property)
  end

  test "record_residential_property resolves from ResidentialProperty" do
    policy = TestPolicy.new(@tenant_admin, @property)

    assert_equal @property, policy.expose_record_residential_property
  end

  test "record_residential_property resolves from PropertySection" do
    policy = TestPolicy.new(@tenant_admin, @section)

    assert_equal @property, policy.expose_record_residential_property
  end

  test "record_residential_property resolves from Unit" do
    policy = TestPolicy.new(@tenant_admin, @unit)

    assert_equal @property, policy.expose_record_residential_property
  end

  test "record_residential_property resolves from UnitOwnership" do
    policy = TestPolicy.new(@tenant_admin, @ownership)

    assert_equal @property, policy.expose_record_residential_property
  end

  test "record_residential_property resolves from UnitOccupancy" do
    policy = TestPolicy.new(@tenant_admin, @occupancy)

    assert_equal @property, policy.expose_record_residential_property
  end

  test "record_residential_property does not resolve property for Person" do
    policy = TestPolicy.new(@tenant_admin, @person)

    assert_nil policy.expose_record_residential_property
  end

  test "allowed? does not grant property scoped capability without resolvable property context" do
    policy = TestPolicy.new(@property_admin, @person)

    refute policy.allowed?(:manage_units)
  end

  test "same_organization? denies records from another organization" do
    policy = TestPolicy.new(@tenant_admin, @other_org_person)

    refute policy.same_organization?
  end

  test "same_organization? allows records in current organization" do
    policy = TestPolicy.new(@tenant_admin, @person)

    assert policy.same_organization?
  end

  private

  def create_property(organization, name)
    ResidentialProperty.create!(
      organization: organization,
      name: name,
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
  end

  def create_unit(property, identifier)
    Unit.create!(
      organization: property.organization,
      residential_property: property,
      identifier: identifier,
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
  end

  def create_staff_user(email:, staff_type:, property:)
    user = create_user_for_organization(
      organization: @organization,
      email: email,
      role: AvailableRoles::CLIENT
    )

    StaffAssignment.create!(
      organization: @organization,
      person: user.person_for(@organization),
      residential_property: property,
      staff_type: staff_type,
      status: "active",
      starts_at: Date.current
    )

    user
  end
end
