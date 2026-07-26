# frozen_string_literal: true

require "test_helper"

# Authorization and scope isolation for ResidentialPropertyPolicy
# (improve-property-foundation §7.12–§7.16).
class ResidentialPropertyPolicyTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property_a = create_property(@organization, "Policy Property A")
    @property_b = create_property(@organization, "Policy Property B")

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "rp-pol-tenant-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @property_admin_a = create_staff_user(
      organization: @organization,
      email: "rp-pol-prop-admin-a@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property_a
    )
    @client = create_user_for_organization(
      organization: @organization,
      email: "rp-pol-client@example.test",
      role: AvailableRoles::CLIENT
    )

    @other_property = ActsAsTenant.with_tenant(@other_organization) do
      create_property(@other_organization, "Other Org Policy Property")
    end
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  # 7.12 ----------------------------------------------------------------------
  test "7.12 tenant_admin can manage properties in own organization" do
    assert ResidentialPropertyPolicy.new(@tenant_admin, ResidentialProperty).index?
    assert ResidentialPropertyPolicy.new(@tenant_admin, ResidentialProperty).create?
    assert ResidentialPropertyPolicy.new(@tenant_admin, @property_a).show?
    assert ResidentialPropertyPolicy.new(@tenant_admin, @property_a).update?
    assert ResidentialPropertyPolicy.new(@tenant_admin, @property_a).archive?
  end

  test "7.12 tenant_admin cannot manage properties in another organization" do
    ActsAsTenant.with_tenant(@other_organization) do
      Current.reset
      refute ResidentialPropertyPolicy.new(@tenant_admin, ResidentialProperty).create?
      refute ResidentialPropertyPolicy.new(@tenant_admin, @other_property).update?
      refute ResidentialPropertyPolicy.new(@tenant_admin, @other_property).archive?
    end
  end

  # 7.13 ----------------------------------------------------------------------
  test "7.13 assigned property_admin can view and update only the assigned property" do
    assert ResidentialPropertyPolicy.new(@property_admin_a, @property_a).show?
    assert ResidentialPropertyPolicy.new(@property_admin_a, @property_a).update?

    refute ResidentialPropertyPolicy.new(@property_admin_a, @property_b).update?
  end

  # 7.6 / 7.13 ----------------------------------------------------------------
  test "7.13 property_admin cannot create or archive by default" do
    refute ResidentialPropertyPolicy.new(@property_admin_a, ResidentialProperty).create?
    refute ResidentialPropertyPolicy.new(@property_admin_a, @property_a).archive?
  end

  # 7.14 ----------------------------------------------------------------------
  test "7.14 inactive, future, or expired assignment grants no manage_property" do
    refute property_admin_update_allowed?(
      email: "rp-pol-inactive@example.test",
      status: StaffAssignment::STATUS_INACTIVE,
      starts_at: Date.current
    ), "inactive assignment must not grant update"

    refute property_admin_update_allowed?(
      email: "rp-pol-future@example.test",
      status: StaffAssignment::STATUS_ACTIVE,
      starts_at: 1.week.from_now.to_date
    ), "future assignment must not grant update"

    refute property_admin_update_allowed?(
      email: "rp-pol-expired@example.test",
      status: StaffAssignment::STATUS_ACTIVE,
      starts_at: 1.year.ago.to_date,
      ends_at: 1.day.ago.to_date
    ), "expired assignment must not grant update"
  end

  # 7.15 ----------------------------------------------------------------------
  test "7.15 user without permissions is denied everything" do
    refute ResidentialPropertyPolicy.new(@client, ResidentialProperty).create?
    refute ResidentialPropertyPolicy.new(@client, @property_a).show?
    refute ResidentialPropertyPolicy.new(@client, @property_a).update?
    refute ResidentialPropertyPolicy.new(@client, @property_a).archive?
  end

  # 7.16 ----------------------------------------------------------------------
  test "7.16 tenant_admin scope is tenant-safe" do
    resolved = ResidentialPropertyPolicy::Scope.new(@tenant_admin, ResidentialProperty.all).resolve
    assert_includes resolved, @property_a
    assert_includes resolved, @property_b
    refute_includes resolved, @other_property
  end

  test "7.16 property_admin scope is limited to assigned properties" do
    resolved = ResidentialPropertyPolicy::Scope.new(@property_admin_a, ResidentialProperty.all).resolve
    assert_includes resolved, @property_a
    refute_includes resolved, @property_b
    refute_includes resolved, @other_property
  end

  private

  # Builds a property-admin whose only assignment on @property_b has the given
  # validity, and returns whether update? is granted.
  def property_admin_update_allowed?(email:, status:, starts_at:, ends_at: nil)
    user = create_user_for_organization(
      organization: @organization,
      email: email,
      role: AvailableRoles::CLIENT
    )
    StaffAssignment.create!(
      organization: @organization,
      person: user.person_for(@organization),
      residential_property: @property_b,
      staff_type: StaffTypes::MANAGER,
      status: status,
      starts_at: starts_at,
      ends_at: ends_at
    )
    Current.reset
    ResidentialPropertyPolicy.new(user, @property_b).update?
  end
end
