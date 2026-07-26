# frozen_string_literal: true

require "test_helper"

# PropertySectionPolicy authorization (improve-property-sections §9.18-9.20):
# tenant admin, assigned property admin, invalid assignments, cross-tenant /
# cross-property and users without the capability.
class PropertySectionPolicyTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property = create_property(@organization, "Policy Property")
    @other_property = create_property(@organization, "Policy Property Two")
    @section = @property.property_sections.create!(
      organization: @organization,
      name: "Torre A",
      section_type: SectionTypes::TOWER
    )

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "policy-tenant-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @client = create_user_for_organization(
      organization: @organization,
      email: "policy-client@example.test",
      role: AvailableRoles::CLIENT
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  # 9.18
  test "tenant admin may manage sections in own organization" do
    policy = policy_for(@tenant_admin, @section)

    assert policy.show?
    assert policy.update?
    assert policy.move?
    assert policy.archive?
  end

  # §"Delete vs archive strategy": destructive deletion is never allowed through
  # the ordinary administrative flow, even for a tenant admin — archive is the
  # only supported retirement operation.
  test "destroy is always denied, even for a tenant admin" do
    assert_not policy_for(@tenant_admin, @section).destroy?

    property_admin = create_staff_user(
      organization: @organization,
      email: "policy-destroy-admin@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )
    assert_not policy_for(property_admin, @section).destroy?
  end

  # 9.18
  test "assigned property admin may manage sections in the property" do
    admin = create_staff_user(
      organization: @organization,
      email: "policy-property-admin@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )

    assert policy_for(admin, @section).update?
  end

  # 9.19
  test "inactive assignment grants no access" do
    admin = create_staff_user(
      organization: @organization,
      email: "policy-inactive-admin@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )
    StaffAssignment.find_by(residential_property: @property).update!(status: "inactive")

    assert_not policy_for(admin, @section).update?
  end

  # 9.19
  test "future-dated assignment grants no access" do
    admin = create_staff_user(
      organization: @organization,
      email: "policy-future-admin@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )
    StaffAssignment.find_by(residential_property: @property)
      .update!(starts_at: Date.current + 5.days)

    assert_not policy_for(admin, @section).update?
  end

  # 9.19
  test "expired assignment grants no access" do
    admin = create_staff_user(
      organization: @organization,
      email: "policy-expired-admin@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )
    StaffAssignment.find_by(residential_property: @property)
      .update!(starts_at: Date.current - 10.days, ends_at: Date.current - 1.day)

    assert_not policy_for(admin, @section).update?
  end

  # 9.20
  test "property admin is denied on a property without assignment" do
    admin = create_staff_user(
      organization: @organization,
      email: "policy-scoped-admin@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )
    foreign_section = @other_property.property_sections.create!(
      organization: @organization,
      name: "Torre Other",
      section_type: SectionTypes::TOWER
    )

    assert_not policy_for(admin, foreign_section).update?
    assert_not policy_scope(admin).exists?(foreign_section.id)
    assert policy_scope(admin).exists?(@section.id)
  end

  # 9.20
  test "cross-organization access is denied and excluded from scope" do
    foreign_section = nil
    ActsAsTenant.with_tenant(@other_organization) do
      foreign_property = create_property(@other_organization, "Foreign Property")
      foreign_section = foreign_property.property_sections.create!(
        organization: @other_organization,
        name: "Torre Foreign",
        section_type: SectionTypes::TOWER
      )
    end

    assert_not policy_for(@tenant_admin, foreign_section).show?
    assert_not policy_scope(@tenant_admin).exists?(foreign_section.id)
  end

  # 9.20
  test "user without manage_sections is denied" do
    policy = policy_for(@client, @section)

    assert_not policy.show?
    assert_not policy.update?
    assert_not policy.archive?
    assert_empty policy_scope(@client)
  end

  # 9.20 / §6.7
  test "mutations are denied under an archived property" do
    @property.update!(status: PropertyStatuses::ARCHIVED)
    policy = policy_for(@tenant_admin, @section.reload)

    assert policy.show?, "viewing remains allowed under an archived property"
    assert_not policy.update?
    assert_not policy.archive?
  end

  private

  def policy_for(user, record)
    PropertySectionPolicy.new(user, record)
  end

  def policy_scope(user)
    PropertySectionPolicy::Scope.new(user, PropertySection).resolve
  end
end
