# frozen_string_literal: true

require "test_helper"

class Admin::ResidentialProperties::UnitsControllerTest < ActionDispatch::IntegrationTest
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Units Show Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
    @unit = Unit.create!(
      organization: @organization,
      residential_property: @property,
      identifier: "UNIT-SHOW-101",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
    @person = Person.create!(
      organization: @organization,
      display_name: "Units Show Occupant",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @active_occupancy = UnitOccupancy.create!(
      organization: @organization,
      unit: @unit,
      person: @person,
      occupancy_type: OccupancyTypes::TENANT,
      can_authorize_visits: true,
      starts_at: Time.zone.parse("2026-06-01 00:00"),
      status: OccupancyStatuses::ACTIVE
    )
    @inactive_person = Person.create!(
      organization: @organization,
      display_name: "Inactive Occupant",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @inactive_occupancy = UnitOccupancy.create!(
      organization: @organization,
      unit: @unit,
      person: @inactive_person,
      occupancy_type: OccupancyTypes::FAMILY_MEMBER,
      starts_at: Time.zone.parse("2025-01-01 00:00"),
      status: OccupancyStatuses::INACTIVE
    )

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "units-show-occupancies@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @unit_show_path = admin_residential_property_unit_path(@property, @unit, tab: "occupants")

    @owner = create_owner_user(
      organization: @organization,
      email: "units-show-visits-owner@example.test",
      unit: @unit
    )

    visitor_person = Person.create!(
      organization: @organization,
      display_name: "Units Show Visit Visitor",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @visit = Visit.create!(
      organization: @organization,
      unit: @unit,
      visitor_person: visitor_person,
      scheduled_at: 1.day.from_now,
      valid_from: 1.day.from_now,
      status: VisitStatuses::PENDING
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "show includes occupancies pagination occupancy types and occupancy stats props" do
    sign_in_as(@tenant_admin)

    inertia_get @unit_show_path
    assert_response :success

    props = inertia_props
    assert_equal 1, props["occupancies"].size
    assert_equal @active_occupancy.id, props["occupancies"].first["id"]
    assert_equal OccupancyTypes::TENANT, props["occupancies"].first["occupancy_type"]
    assert_equal I18n.t("frontend.admin.unit_occupancies.occupancy_types.tenant"), props["occupancies"].first["occupancy_type_label"]
    assert props["occupancies"].first["can_authorize_visits"]
    assert_equal 1, props.dig("occupancies_pagination", "total_count")
    assert_equal OccupancyTypes::ALL.size, props["occupancy_types"].size
    assert_equal 1, props.dig("unit", "occupancy_stats", "active_occupants_count")
    assert_equal 1, props.dig("unit", "occupancy_stats", "active_authorizers_count")
    assert_equal 1, props.dig("unit", "occupancy_stats", "historical_occupants_count")
    assert_equal 2, props.dig("unit", "occupancy_stats", "total_occupants_count")
    assert_equal true, props.dig("occupancy_permissions", "create")
    assert_equal true, props.dig("occupancy_permissions", "update")
    assert_equal true, props.dig("occupancy_permissions", "destroy")
    assert_equal false, props["occupancies_include_inactive"]
  end

  test "show excludes inactive occupancies by default" do
    sign_in_as(@tenant_admin)

    inertia_get @unit_show_path
    assert_response :success

    occupant_ids = inertia_props["occupancies"].map { |occupancy| occupancy["id"] }
    assert_includes occupant_ids, @active_occupancy.id
    assert_not_includes occupant_ids, @inactive_occupancy.id
  end

  test "show includes inactive occupancies when requested" do
    sign_in_as(@tenant_admin)

    inertia_get admin_residential_property_unit_path(
      @property,
      @unit,
      tab: "occupants",
      occupancies_include_inactive: true
    )
    assert_response :success

    occupant_ids = inertia_props["occupancies"].map { |occupancy| occupancy["id"] }
    assert_includes occupant_ids, @active_occupancy.id
    assert_includes occupant_ids, @inactive_occupancy.id
    assert_equal @active_occupancy.id, occupant_ids.first
  end

  test "show reflects translated occupancy type and status labels in occupancies" do
    sign_in_as(@tenant_admin)

    inertia_get @unit_show_path
    assert_response :success

    row = inertia_props["occupancies"].first
    assert_equal I18n.t("frontend.admin.unit_occupancies.occupancy_types.tenant"), row["occupancy_type_label"]
    assert_equal I18n.t("frontend.admin.units.show.occupants.statuses.active"), row["status_label"]
  end

  test "show includes scoped visits pagination and visit permissions for unit tab" do
    sign_in_as(@owner)

    inertia_get admin_residential_property_unit_path(@property, @unit, tab: "visits")
    assert_response :success

    props = inertia_props
    assert_equal 1, props["visits"].size
    assert_equal @visit.id, props["visits"].first["id"]
    assert_equal 1, props.dig("visits_pagination", "total_count")
    assert props.dig("visit_permissions", "create")
  end

  test "show returns empty visits list when unit has no visits" do
    sign_in_as(@tenant_admin)

    empty_unit = Unit.create!(
      organization: @organization,
      residential_property: @property,
      identifier: "UNIT-SHOW-NO-VISITS",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )

    inertia_get admin_residential_property_unit_path(@property, empty_unit, tab: "visits")
    assert_response :success

    assert_equal [], inertia_props["visits"]
    assert_equal 0, inertia_props.dig("visits_pagination", "total_count")
    assert inertia_props.dig("visit_permissions", "create")
  end

  test "show returns empty occupancies list when unit has no active occupants" do
    sign_in_as(@tenant_admin)

    empty_unit = Unit.create!(
      organization: @organization,
      residential_property: @property,
      identifier: "UNIT-SHOW-EMPTY",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )

    inertia_get admin_residential_property_unit_path(@property, empty_unit, tab: "occupants")
    assert_response :success

    assert_equal [], inertia_props["occupancies"]
    assert_equal 0, inertia_props.dig("occupancies_pagination", "total_count")
    assert_equal 0, inertia_props.dig("unit", "occupancy_stats", "active_occupants_count")
  end

  private

  def sign_in_as(user)
    host! "#{@organization.subdomain}.example.com"
    post user_session_path, params: {
      user: { email: user.email, password: "Password1@" }
    }
  end
end
