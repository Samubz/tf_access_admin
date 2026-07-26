# frozen_string_literal: true

require "test_helper"

class AuthorizationResolverTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property_a = create_property(@organization, "Property A")
    @property_b = create_property(@organization, "Property B")
    @other_org_property = ActsAsTenant.with_tenant(@other_organization) do
      create_property(@other_organization, "Other Org Property")
    end

    @unit_a = create_unit(@property_a, "UNIT-A-101")
    @unit_b = create_unit(@property_b, "UNIT-B-101")
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "tenant_admin retains organization-wide access" do
    user = create_user_for_organization(
      organization: @organization,
      email: "tenant-admin-resolver@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    resolver = build_resolver(user)

    assert resolver.allowed?(:manage_users)
    assert resolver.allowed?(:manage_units)
    assert resolver.allowed?(:manage_ownerships)
    assert_includes resolver.accessible_property_ids, @property_a.id
    assert_includes resolver.accessible_property_ids, @property_b.id
  end

  test "tenant_admin cannot access another organization" do
    user = create_user_for_organization(
      organization: @organization,
      email: "tenant-admin-cross-org@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    other_org_resolver = Authorization::Resolver.new(
      user: user,
      organization: @other_organization,
      property: @other_org_property
    )

    refute other_org_resolver.allowed?(:manage_users)
    refute other_org_resolver.allowed?(:manage_units)
    refute other_org_resolver.property_accessible?(@other_org_property)
    refute_includes other_org_resolver.accessible_property_ids, @other_org_property.id

    own_org_resolver = build_resolver(user, property: @other_org_property)
    refute own_org_resolver.allowed?(:manage_units)
    refute own_org_resolver.property_accessible?(@other_org_property)
  end

  test "property_admin accesses only assigned property" do
    user = create_staff_user(
      email: "property-admin-a@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property_a
    )
    resolver = build_resolver(user, property: @property_a)

    assert resolver.allowed?(:manage_units)
    assert resolver.allowed?(:manage_ownerships)
    assert resolver.allowed?(:manage_staff_assignments)
  end

  test "property_admin cannot access another property" do
    user = create_staff_user(
      email: "property-admin-deny-b@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property_a
    )
    resolver = build_resolver(user, property: @property_b)

    refute resolver.allowed?(:manage_units)
    refute resolver.allowed?(:manage_ownerships)
    refute_includes resolver.accessible_property_ids, @property_b.id
  end

  test "concierge accesses only assigned property visit capabilities" do
    user = create_staff_user(
      email: "concierge-a@example.test",
      staff_type: StaffTypes::CONCIERGE,
      property: @property_a
    )
    resolver = build_resolver(user, property: @property_a)

    assert resolver.allowed?(:view_visits)
    assert resolver.allowed?(:register_visit_entry)
    assert resolver.allowed?(:view_minimal_access_control_data)
  end

  test "concierge does not receive administrative permissions" do
    user = create_staff_user(
      email: "concierge-admin-deny@example.test",
      staff_type: StaffTypes::CONCIERGE,
      property: @property_a
    )
    resolver = build_resolver(user, property: @property_a)

    refute resolver.allowed?(:manage_units)
    refute resolver.allowed?(:manage_people)
    refute resolver.allowed?(:manage_ownerships)
    refute resolver.allowed?(:manage_users)
  end

  test "concierge cannot access another property" do
    user = create_staff_user(
      email: "concierge-deny-b@example.test",
      staff_type: StaffTypes::CONCIERGE,
      property: @property_a
    )
    resolver = build_resolver(user, property: @property_b)

    refute resolver.allowed?(:view_visits)
    refute resolver.allowed?(:register_visit_entry)
    refute_includes resolver.accessible_property_ids, @property_b.id
  end

  test "cleaning_staff and internal_staff do not receive administrative permissions by default" do
    cleaning_user = create_staff_user(
      email: "cleaning-staff@example.test",
      staff_type: StaffTypes::CLEANING,
      property: @property_a
    )
    internal_user = create_staff_user(
      email: "internal-staff@example.test",
      staff_type: StaffTypes::MAINTENANCE,
      property: @property_a
    )

    cleaning_resolver = build_resolver(cleaning_user, property: @property_a)
    internal_resolver = build_resolver(internal_user, property: @property_a)

    refute cleaning_resolver.allowed?(:manage_units)
    refute cleaning_resolver.allowed?(:manage_people)
    refute internal_resolver.allowed?(:manage_units)
    refute internal_resolver.allowed?(:manage_ownerships)
  end

  test "owner receives unit-scoped visit capabilities" do
    user = create_user_for_organization(
      organization: @organization,
      email: "owner-resolver@example.test",
      role: AvailableRoles::CLIENT
    )
    person = user.person_for(@organization)
    create_ownership(person:, unit: @unit_a)

    resolver = build_resolver(user, unit: @unit_a)

    assert resolver.allowed?(:create_visits)
    assert resolver.allowed?(:authorize_visits)
    assert resolver.allowed?(:view_own_unit_context)
    refute build_resolver(user, unit: @unit_b).allowed?(:create_visits)
  end

  test "resident receives unit-scoped capabilities only for active units" do
    user = create_user_for_organization(
      organization: @organization,
      email: "resident-resolver@example.test",
      role: AvailableRoles::CLIENT
    )
    person = user.person_for(@organization)
    create_occupancy(person:, unit: @unit_a, can_authorize_visits: true)

    resolver = build_resolver(user, unit: @unit_a)
    other_unit_resolver = build_resolver(user, unit: @unit_b)

    assert resolver.allowed?(:create_visits)
    assert resolver.allowed?(:authorize_visits)
    assert resolver.allowed?(:view_own_unit_context)
    refute other_unit_resolver.allowed?(:create_visits)
  end

  test "client without assignments receives no admin access" do
    user = create_user_for_organization(
      organization: @organization,
      email: "client-no-access@example.test",
      role: AvailableRoles::CLIENT
    )
    resolver = build_resolver(user, property: @property_a)

    refute resolver.allowed?(:manage_units)
    refute resolver.allowed?(:manage_people)
    refute resolver.allowed?(:view_visits)
    assert_empty resolver.accessible_property_ids
  end

  test "inactive staff assignment does not grant capabilities" do
    user = create_staff_user(
      email: "inactive-staff@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property_a,
      status: "inactive"
    )
    resolver = build_resolver(user, property: @property_a)

    refute resolver.allowed?(:manage_units)
  end

  test "expired staff assignment does not grant capabilities" do
    user = create_staff_user(
      email: "expired-staff@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property_a,
      starts_at: 30.days.ago.to_date,
      ends_at: Date.current - 1.day
    )
    resolver = build_resolver(user, property: @property_a)

    refute resolver.allowed?(:manage_units)
  end

  test "memoization does not leak permissions between property contexts" do
    user = create_staff_user(
      email: "memoization-staff@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property_a
    )

    Current.user = user
    Current.organization = @organization

    resolver_p = Current.authorization_resolver(property: @property_a)
    resolver_q = Current.authorization_resolver(property: @property_b)

    assert resolver_p.allowed?(:manage_units)
    refute resolver_q.allowed?(:manage_units)

    assert_equal Current.authorization_grant_profile.object_id, resolver_p.profile.object_id
    assert_equal Current.authorization_grant_profile.object_id, resolver_q.profile.object_id
    refute_equal resolver_p.object_id, resolver_q.object_id
  end

  test "property scoped roles are never resolved from global tenant roles" do
    user = create_user_for_organization(
      organization: @organization,
      email: "global-manager-role@example.test",
      role: AvailableRoles::MANAGER
    )
    resolver = build_resolver(user, property: @property_a)

    refute resolver.allowed?(:manage_units)
    refute resolver.allowed?(:manage_property)
    refute resolver.allowed?(:view_visits)
  end

  test "unknown capability returns false" do
    user = create_user_for_organization(
      organization: @organization,
      email: "unknown-capability@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    resolver = build_resolver(user)

    refute resolver.allowed?(:not_a_real_capability)
  end

  private

  def build_resolver(user, property: nil, unit: nil, record: nil)
    Authorization::Resolver.new(
      user: user,
      organization: @organization,
      property: property,
      unit: unit,
      record: record
    )
  end

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

  def create_staff_user(email:, staff_type:, property:, status: "active", starts_at: Date.current, ends_at: nil)
    user = create_user_for_organization(
      organization: @organization,
      email: email,
      role: AvailableRoles::CLIENT
    )
    person = user.person_for(@organization)

    StaffAssignment.create!(
      organization: @organization,
      person: person,
      residential_property: property,
      staff_type: staff_type,
      status: status,
      starts_at: starts_at,
      ends_at: ends_at
    )

    user
  end

  def create_ownership(person:, unit:)
    UnitOwnership.create!(
      organization: @organization,
      person: person,
      unit: unit,
      ownership_percentage: 100,
      starts_at: Date.current,
      status: UnitOwnership::STATUS_ACTIVE
    )
  end

  def create_occupancy(person:, unit:, can_authorize_visits: false)
    UnitOccupancy.create!(
      organization: @organization,
      person: person,
      unit: unit,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: Time.zone.now,
      status: OccupancyStatuses::ACTIVE,
      can_authorize_visits: can_authorize_visits
    )
  end
end
