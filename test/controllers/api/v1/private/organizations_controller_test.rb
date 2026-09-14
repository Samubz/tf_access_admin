# frozen_string_literal: true

require "test_helper"

# GET /api/v1/private/organization/:id and
# GET /api/v1/private/organization/:id/residential_property/:property_id
# mobile-private-api "Organization detail endpoints".
class Api::V1::Private::OrganizationsControllerTest < ActionDispatch::IntegrationTest
  include OperationalPolicyTestHelper
  include Devise::Test::IntegrationHelpers

  setup do
    @organization = organizations(:one)
    @other_org    = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property_p = create_property(@organization, "Org API Property P")
    @property_p.update!(address_line: "Av. Siempre Viva 123", city: "Santiago", region: "RM")
    @property_q = create_property(@organization, "Org API Property Q")
    @property_r = create_property(@organization, "Org API Property R")

    @unit_u = create_unit(@property_p, "OA-P-U")
    @unit_u.update!(display_name: "Casa U")
    @unit_v = create_unit(@property_p, "OA-P-V")
    @unit_w = create_unit(@property_p, "OA-P-W")
    @unit_q = create_unit(@property_q, "OA-Q-1")
    create_unit(@property_r, "OA-R-1")

    @resident = create_user_for_organization(
      organization: @organization,
      email: "org-api-resident@example.test",
      role: AvailableRoles::CLIENT
    )
    person = @resident.person_for(@organization)
    UnitOwnership.create!(
      organization: @organization, person: person, unit: @unit_u,
      ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
    )
    UnitOccupancy.create!(
      organization: @organization, person: person, unit: @unit_v,
      occupancy_type: OccupancyTypes::TENANT, starts_at: 7.days.ago,
      status: OccupancyStatuses::ACTIVE
    )
    UnitOccupancy.create!(
      organization: @organization, person: person, unit: @unit_q,
      occupancy_type: OccupancyTypes::FAMILY_MEMBER, starts_at: 7.days.ago,
      status: OccupancyStatuses::ACTIVE
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "organization detail lists only related properties and units with owner flag" do
    get_as(@resident, api_v1_private_organization_path(id: @organization.id))

    assert_response :ok
    data = JSON.parse(response.body).fetch("data")
    assert_equal @organization.name, data["name"]
    assert_nil data["logo"]
    assert_nil data["cover"]

    properties = data.fetch("residentialProperties")
    assert_equal [ @property_p.id, @property_q.id ].sort, properties.map { |p| p["id"] }.sort

    prop_p = properties.find { |p| p["id"] == @property_p.id }
    assert_equal "Org API Property P", prop_p["name"]
    assert_equal PropertyTypes::BUILDING, prop_p["propertyType"]
    assert_equal({ "addressLine" => "Av. Siempre Viva 123", "city" => "Santiago", "region" => "RM" }, prop_p["address"])
    assert_equal @organization.id, prop_p["organizationId"]

    units = prop_p.fetch("units").index_by { |u| u["id"] }
    assert_equal [ @unit_u.id, @unit_v.id ].sort, units.keys.sort

    assert_equal "OA-P-U", units[@unit_u.id]["code"]
    assert_equal "Casa U", units[@unit_u.id]["displayName"]
    assert_equal UnitTypes::APARTMENT, units[@unit_u.id]["unitType"]
    assert_equal true, units[@unit_u.id]["isOwner"]
    assert_nil units[@unit_u.id]["occupancyType"]

    assert_equal false, units[@unit_v.id]["isOwner"]
    assert_equal OccupancyTypes::TENANT, units[@unit_v.id]["occupancyType"]
  end

  test "organization detail with another organization's id returns 404" do
    get_as(@resident, api_v1_private_organization_path(id: @other_org.id))

    assert_response :not_found
  end

  test "organization detail without token returns 401" do
    host! "#{@organization.subdomain}.example.com"
    get api_v1_private_organization_path(id: @organization.id), headers: { "Accept" => "application/json" }

    assert_response :unauthorized
  end

  test "organization detail for a non-member returns 403" do
    outsider = create_user_for_organization(
      organization: @other_org,
      email: "org-api-outsider@example.test",
      role: AvailableRoles::CLIENT
    )

    get_as(outsider, api_v1_private_organization_path(id: @organization.id))

    assert_response :forbidden
  end

  test "residential property detail returns one related property" do
    get_as(@resident, api_v1_private_organization_residential_property_path(id: @organization.id, property_id: @property_q.id))

    assert_response :ok
    data = JSON.parse(response.body).fetch("data")
    assert_equal @property_q.id, data["id"]
    assert_equal [ @unit_q.id ], data.fetch("units").map { |u| u["id"] }
    assert_equal OccupancyTypes::FAMILY_MEMBER, data["units"].first["occupancyType"]
  end

  test "residential property without active relationship returns 404" do
    get_as(@resident, api_v1_private_organization_residential_property_path(id: @organization.id, property_id: @property_r.id))

    assert_response :not_found
  end

  test "residential property with another organization's id returns 404" do
    get_as(@resident, api_v1_private_organization_residential_property_path(id: @other_org.id, property_id: @property_p.id))

    assert_response :not_found
  end

  test "residential property without token returns 401" do
    host! "#{@organization.subdomain}.example.com"
    get api_v1_private_organization_residential_property_path(id: @organization.id, property_id: @property_p.id), headers: { "Accept" => "application/json" }

    assert_response :unauthorized
  end

  private

  def get_as(user, path)
    host! "#{@organization.subdomain}.example.com"
    sign_in user
    get path
    sign_out user
  end
end
