# frozen_string_literal: true

require "test_helper"

# Isolation and regression tests for OperationalRolePolicy.
#
# Covers tasks 10.1 (cross-org denial), 10.2 (cross-property denial),
# 10.3 (tenant_admin org-wide access), 10.6 (property_admin of A cannot
# access B), and 10.7 (concierge of A cannot access data of B).
class OperationalRolePolicyTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property_a = create_property(@organization, "OR Policy Property A")
    @property_b = create_property(@organization, "OR Policy Property B")

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "or-pol-tenant-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    # property_admin assigned only to property A
    @property_admin_a = create_staff_user(
      organization: @organization,
      email: "or-pol-prop-admin-a@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property_a
    )

    # concierge assigned only to property A
    @concierge_a = create_staff_user(
      organization: @organization,
      email: "or-pol-concierge-a@example.test",
      staff_type: StaffTypes::CONCIERGE,
      property: @property_a
    )

    @client = create_user_for_organization(
      organization: @organization,
      email: "or-pol-client@example.test",
      role: AvailableRoles::CLIENT
    )

    # Active assignment on property A — used as the record for destroy?
    @staff_person = create_user_for_organization(
      organization: @organization,
      email: "or-pol-staff-person@example.test",
      role: AvailableRoles::CLIENT
    ).person_for(@organization)

    @assignment_a = StaffAssignment.create!(
      organization: @organization,
      person: @staff_person,
      residential_property: @property_a,
      staff_type: StaffTypes::CONCIERGE,
      status: StaffAssignment::STATUS_ACTIVE,
      starts_at: Date.current
    )

    @assignment_b = StaffAssignment.create!(
      organization: @organization,
      person: @staff_person,
      residential_property: @property_b,
      staff_type: StaffTypes::CONCIERGE,
      status: StaffAssignment::STATUS_ACTIVE,
      starts_at: Date.current
    )

    # Assignment in another organization
    @other_person = ActsAsTenant.with_tenant(@other_organization) do
      Person.create!(
        organization: @other_organization,
        display_name: "Other Org Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
    end
    @other_property = ActsAsTenant.with_tenant(@other_organization) do
      create_property(@other_organization, "Other Org OR Policy Property")
    end
    @other_assignment = ActsAsTenant.without_tenant do
      StaffAssignment.create!(
        organization: @other_organization,
        person: @other_person,
        residential_property: @other_property,
        staff_type: StaffTypes::MANAGER,
        status: StaffAssignment::STATUS_ACTIVE,
        starts_at: Date.current
      )
    end
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  # ---------------------------------------------------------------------------
  # 10.3 — tenant_admin conserves org-wide access
  # ---------------------------------------------------------------------------

  test "10.3 tenant_admin can manage operational roles org-wide" do
    policy = OperationalRolePolicy.new(@tenant_admin, nil)
    assert policy.index?
    assert policy.show?
    assert policy.create?
  end

  test "10.3 tenant_admin can revoke any assignment within the organization" do
    assert OperationalRolePolicy.new(@tenant_admin, @assignment_a).destroy?
    assert OperationalRolePolicy.new(@tenant_admin, @assignment_b).destroy?
  end

  # ---------------------------------------------------------------------------
  # 10.1 — cross-organization denial
  # ---------------------------------------------------------------------------

  test "10.1 tenant_admin of org1 is denied index on org2 tenant context" do
    ActsAsTenant.with_tenant(@other_organization) do
      Current.reset
      policy = OperationalRolePolicy.new(@tenant_admin, nil)
      refute policy.index?
    end
  end

  test "10.1 cross-org assignment is excluded by Scope" do
    resolved = OperationalRolePolicy::Scope.new(@tenant_admin, StaffAssignment.all).resolve
    assert_includes resolved, @assignment_a
    assert_includes resolved, @assignment_b
    refute_includes resolved, @other_assignment
  end

  test "10.1 client has no access to operational role management" do
    policy = OperationalRolePolicy.new(@client, nil)
    refute policy.index?
    refute policy.create?
    refute OperationalRolePolicy.new(@client, @assignment_a).destroy?
  end

  # ---------------------------------------------------------------------------
  # 10.2 — cross-property denial for property_admin (task 10.6)
  # ---------------------------------------------------------------------------

  test "10.6 property_admin of A can manage operational roles on A" do
    assert OperationalRolePolicy.new(@property_admin_a, nil).index?
    assert OperationalRolePolicy.new(@property_admin_a, @assignment_a).destroy?
  end

  test "10.6 property_admin of A cannot revoke assignment on B" do
    refute OperationalRolePolicy.new(@property_admin_a, @assignment_b).destroy?
  end

  test "10.6 property_admin scope excludes property B assignments" do
    resolved = OperationalRolePolicy::Scope.new(@property_admin_a, StaffAssignment.all).resolve
    assert_includes resolved, @assignment_a
    refute_includes resolved, @assignment_b
    refute_includes resolved, @other_assignment
  end

  # ---------------------------------------------------------------------------
  # 10.2 — cross-property denial for concierge (task 10.7)
  # ---------------------------------------------------------------------------

  test "10.7 concierge of A has no manage_staff_assignments capability" do
    policy = OperationalRolePolicy.new(@concierge_a, nil)
    refute policy.index?
    refute policy.create?
  end

  test "10.7 concierge of A cannot revoke any assignment" do
    refute OperationalRolePolicy.new(@concierge_a, @assignment_a).destroy?
    refute OperationalRolePolicy.new(@concierge_a, @assignment_b).destroy?
  end

  test "10.7 concierge scope is empty for staff assignments" do
    resolved = OperationalRolePolicy::Scope.new(@concierge_a, StaffAssignment.all).resolve
    assert_empty resolved
  end
end
