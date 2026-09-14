# frozen_string_literal: true

require "test_helper"

# GET /api/v1/private/units — mobile-private-api "Units endpoint".
class Api::V1::Private::UnitsControllerTest < ActionDispatch::IntegrationTest
  include OperationalPolicyTestHelper
  include Devise::Test::IntegrationHelpers

  setup do
    @organization = organizations(:one)
    @other_org    = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property = create_property(@organization, "Units API Property")
    @unit_1   = create_unit(@property, "UN-101")
    @unit_2   = create_unit(@property, "UN-102")
    @unit_2.update!(display_name: "Depto 102")
    @unit_3   = create_unit(@property, "UN-103")

    @resident = create_user_for_organization(
      organization: @organization,
      email: "units-api-resident@example.test",
      role: AvailableRoles::CLIENT
    )
    person = @resident.person_for(@organization)
    UnitOccupancy.create!(
      organization: @organization, person: person, unit: @unit_1,
      occupancy_type: OccupancyTypes::TENANT, starts_at: 7.days.ago,
      status: OccupancyStatuses::ACTIVE, can_authorize_visits: true
    )
    UnitOwnership.create!(
      organization: @organization, person: person, unit: @unit_2,
      ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
    )
    # Ended occupancy must not surface
    UnitOccupancy.create!(
      organization: @organization, person: person, unit: @unit_3,
      occupancy_type: OccupancyTypes::TENANT, starts_at: 30.days.ago, ends_at: 2.days.ago,
      status: OccupancyStatuses::ACTIVE
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "lists only units with an active occupancy or ownership" do
    get_units(@resident)

    assert_response :ok
    data = JSON.parse(response.body).fetch("data")
    assert_equal [ @unit_1.id, @unit_2.id ].sort, data.map { |u| u["id"] }.sort

    by_id = data.index_by { |u| u["id"] }
    assert_equal "UN-101", by_id[@unit_1.id]["name"]
    assert_equal "Depto 102", by_id[@unit_2.id]["name"]
    assert_equal({ "id" => @organization.id, "name" => @organization.name }, by_id[@unit_1.id]["organization"])
  end

  test "member without unit relationships gets an empty list" do
    stranger = create_user_for_organization(
      organization: @organization,
      email: "units-api-stranger@example.test",
      role: AvailableRoles::CLIENT
    )

    get_units(stranger)

    assert_response :ok
    assert_equal [], JSON.parse(response.body).fetch("data")
  end

  test "without token returns 401" do
    host! "#{@organization.subdomain}.example.com"
    get api_v1_private_units_path, headers: { "Accept" => "application/json" }

    assert_response :unauthorized
  end

  test "user from another organization returns 403" do
    outsider = create_user_for_organization(
      organization: @other_org,
      email: "units-api-outsider@example.test",
      role: AvailableRoles::CLIENT
    )

    get_units(outsider)

    assert_response :forbidden
  end

  private

  def get_units(user)
    host! "#{@organization.subdomain}.example.com"
    sign_in user
    get api_v1_private_units_path, headers: { "Accept" => "application/json" }
    sign_out user
  end
end
