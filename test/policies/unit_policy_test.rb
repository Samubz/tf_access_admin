# frozen_string_literal: true

require "test_helper"

class UnitPolicyTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property = create_property(@organization, "Unit Policy Property")
    @other_property = create_property(@organization, "Unit Policy Property Two")
    @unit = create_unit(@property, "POL-101")
    @other_unit = create_unit(@other_property, "POL-201")

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "unit-policy-tenant-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @client = create_user_for_organization(
      organization: @organization,
      email: "unit-policy-client@example.test",
      role: AvailableRoles::CLIENT
    )
    @owner = create_owner_user(
      organization: @organization,
      email: "unit-policy-owner@example.test",
      unit: @other_unit
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "tenant admin may view and manage units in own organization" do
    policy = policy_for(@tenant_admin, @unit)

    assert policy.show?
    assert policy.update?
    assert policy.move?
    assert policy.archive?
    assert policy.restore?
    assert policy.soft_delete?
  end

  test "tenant admin may create with explicit destination property" do
    draft = Unit.new(residential_property: @property, organization: @organization)

    assert policy_for(@tenant_admin, draft).create?
  end

  test "create requires explicit destination property" do
    assert_not policy_for(@tenant_admin, Unit).create?
  end

  test "assigned property admin may manage units on assigned property only" do
    admin = create_staff_user(
      organization: @organization,
      email: "unit-policy-property-admin@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )

    assert policy_for(admin, @unit).show?
    assert policy_for(admin, @unit).update?
    assert_not policy_for(admin, @other_unit).show?
    assert_not policy_for(admin, @other_unit).update?
  end

  test "property admin may create with explicit destination property" do
    admin = create_staff_user(
      organization: @organization,
      email: "unit-policy-property-admin-create@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )
    draft = Unit.new(residential_property: @property, organization: @organization)

    assert policy_for(admin, draft).create?
  end

  test "property admin cannot create in another property" do
    admin = create_staff_user(
      organization: @organization,
      email: "unit-policy-property-admin-other@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )
    draft = Unit.new(residential_property: @other_property, organization: @organization)

    assert_not policy_for(admin, draft).create?
  end

  test "actor with manage_units in one property cannot create in another" do
    admin = create_staff_user(
      organization: @organization,
      email: "unit-policy-multi-property@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )
    draft = Unit.new(residential_property: @other_property, organization: @organization)

    assert_not policy_for(admin, draft).create?
  end

  test "create is denied for cross-organization property" do
    other_org = organizations(:two)
    other_org_property = ActsAsTenant.with_tenant(other_org) do
      create_property(other_org, "Foreign Property")
    end
    draft = Unit.new(residential_property: other_org_property, organization: other_org)

    assert_not policy_for(@tenant_admin, draft).create?
  end

  test "inactive assignment grants no access" do
    admin = create_staff_user(
      organization: @organization,
      email: "unit-policy-inactive-admin@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )
    StaffAssignment.find_by(residential_property: @property).update!(status: "inactive")

    assert_not policy_for(admin, @unit).show?
    assert_not policy_for(admin, @unit).update?
  end

  test "future-dated assignment grants no access" do
    admin = create_staff_user(
      organization: @organization,
      email: "unit-policy-future-admin@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )
    StaffAssignment.find_by(residential_property: @property)
      .update!(starts_at: Date.current + 5.days)

    assert_not policy_for(admin, @unit).update?
  end

  test "expired assignment grants no access" do
    admin = create_staff_user(
      organization: @organization,
      email: "unit-policy-expired-admin@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )
    StaffAssignment.find_by(residential_property: @property)
      .update!(starts_at: Date.current - 10.days, ends_at: Date.current - 1.day)

    assert_not policy_for(admin, @unit).update?
  end

  test "concierge cannot read or mutate without view_units capability" do
    concierge = create_staff_user(
      organization: @organization,
      email: "unit-policy-concierge@example.test",
      staff_type: StaffTypes::CONCIERGE,
      property: @property
    )

    assert_not policy_for(concierge, @unit).show?
    assert_not policy_for(concierge, @unit).update?
  end

  test "concierge may read when assignment grants view_units" do
    concierge = create_staff_user(
      organization: @organization,
      email: "unit-policy-concierge-view@example.test",
      staff_type: StaffTypes::CONCIERGE,
      property: @property
    )
    grant_property_capabilities(
      concierge,
      @property,
      [ Authorization::Capabilities::VIEW_UNITS ]
    )

    policy = policy_for(concierge, @unit)

    assert policy.show?
    assert_not policy.update?
    assert_not policy.archive?
  end

  test "view_units without manage_units allows read but denies mutations" do
    viewer = create_user_for_organization(
      organization: @organization,
      email: "unit-policy-viewer@example.test",
      role: AvailableRoles::CLIENT
    )
    StaffAssignment.create!(
      organization: @organization,
      person: viewer.person_for(@organization),
      residential_property: @property,
      staff_type: StaffTypes::MANAGER,
      status: "active",
      starts_at: Date.current
    )
    grant_property_capabilities(
      viewer,
      @property,
      [ Authorization::Capabilities::VIEW_UNITS ]
    )

    policy = policy_for(viewer, @unit)

    assert policy.show?
    assert_not policy.update?
    assert_not policy.move?
    assert_not policy.archive?
  end

  test "owner can view own unit without admin permissions" do
    assert policy_for(@owner, @other_unit).show?
    assert_not policy_for(@owner, @other_unit).update?
    assert_not policy_for(@owner, @unit).show?
  end

  test "client without assignments is denied and scoped out" do
    assert_not policy_for(@client, @unit).show?
    assert_not policy_for(@client, @unit).update?
    assert_empty policy_scope(@client)
  end

  test "cross-organization access is denied and excluded from scope" do
    foreign_unit = ActsAsTenant.with_tenant(@other_organization) do
      property = create_property(@other_organization, "Foreign Unit Property")
      create_unit(property, "FOR-101")
    end

    assert_not policy_for(@tenant_admin, foreign_unit).show?
    assert_not policy_scope(@tenant_admin).exists?(foreign_unit.id)
  end

  test "property-scoped actor only sees assigned property units" do
    admin = create_staff_user(
      organization: @organization,
      email: "unit-policy-scope-admin@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )
    scope = policy_scope(admin)

    assert_includes scope, @unit
    assert_not_includes scope, @other_unit
  end

  test "mutations are denied under an archived property" do
    @property.update!(status: PropertyStatuses::ARCHIVED)
    policy = policy_for(@tenant_admin, @unit.reload)

    assert policy.show?
    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.move?
    assert_not policy.archive?
  end

  test "global manager role without staff assignment does not grant unit access" do
    global_manager = create_user_for_organization(
      organization: @organization,
      email: "unit-policy-global-manager@example.test",
      role: AvailableRoles::MANAGER
    )

    assert_not policy_for(global_manager, @unit).show?
    assert_not policy_for(global_manager, @unit).update?
  end

  private

  def policy_for(user, record)
    UnitPolicy.new(user, record)
  end

  def policy_scope(user)
    UnitPolicy::Scope.new(user, Unit.all).resolve
  end

  def grant_property_capabilities(user, property, capabilities)
    profile = Authorization::GrantProfile.build(user, @organization)
    profile.instance_variable_set(
      :@property_capabilities,
      { property.id => Set.new(capabilities) }
    )
    Current.user = user
    Current.organization = @organization
    Current.authorization_grant_profile = profile
  end
end
