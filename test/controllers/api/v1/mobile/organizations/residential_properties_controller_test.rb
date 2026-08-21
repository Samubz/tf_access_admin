# frozen_string_literal: true

require "test_helper"

class Api::V1::Mobile::Organizations::ResidentialPropertiesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @organization = organizations(:one)
    @user = create_user_for_organization(
      organization: @organization,
      email: "mobile-rp-detail@example.com",
      role: AvailableRoles::CLIENT
    )
    @person = ActsAsTenant.with_tenant(@organization) { @user.person_for(@organization) }
    @property = create_property!(status: PropertyStatuses::ACTIVE)
  end

  test "member fetches residential property detail with an eligible unit" do
    unit = create_unit!(property: @property, status: UnitStatuses::AVAILABLE)
    own_unit!(unit)
    sign_in @user

    get api_v1_mobile_organization_residential_property_path(organization_id: @organization.id, id: @property.id)

    assert_response :ok
    body = response.parsed_body
    assert_equal @property.id, body.dig("data", "id")
    assert_equal @property.name, body.dig("data", "name")
    assert_equal @property.address_line, body.dig("data", "address", "address_line")
    assert_equal 1, body.dig("data", "units").size
    assert_equal unit.id, body.dig("data", "units").first["id"]
  end

  test "non-member is rejected with not found" do
    other_organization = organizations(:two)
    sign_in @user

    get api_v1_mobile_organization_residential_property_path(organization_id: other_organization.id, id: @property.id)

    assert_response :not_found
  end

  test "nonexistent organization id is rejected with not found" do
    sign_in @user

    get api_v1_mobile_organization_residential_property_path(organization_id: SecureRandom.uuid, id: @property.id)

    assert_response :not_found
  end

  test "nonexistent residential property id is rejected with not found" do
    sign_in @user

    get api_v1_mobile_organization_residential_property_path(organization_id: @organization.id, id: SecureRandom.uuid)

    assert_response :not_found
  end

  test "non-active residential property is rejected with not found" do
    inactive_property = create_property!(status: PropertyStatuses::INACTIVE)
    unit = create_unit!(property: inactive_property, status: UnitStatuses::AVAILABLE)
    own_unit!(unit)
    sign_in @user

    get api_v1_mobile_organization_residential_property_path(organization_id: @organization.id, id: inactive_property.id)

    assert_response :not_found
  end

  test "member with no eligible units in the property is rejected with not found" do
    sign_in @user

    get api_v1_mobile_organization_residential_property_path(organization_id: @organization.id, id: @property.id)

    assert_response :not_found
  end

  test "unauthenticated request is rejected" do
    get api_v1_mobile_organization_residential_property_path(organization_id: @organization.id, id: @property.id),
      headers: { "Accept" => "application/json" }

    assert_response :unauthorized
  end

  private

  def own_unit!(unit)
    ActsAsTenant.with_tenant(@organization) do
      UnitOwnership.create!(
        organization: @organization, unit: unit, person: @person,
        ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
      )
    end
  end

  def create_property!(status:)
    ActsAsTenant.with_tenant(@organization) do
      ResidentialProperty.create!(
        organization: @organization,
        name: "RP Controller Test #{SecureRandom.hex(4)}",
        property_type: PropertyTypes::BUILDING,
        status: status,
        country: "Chile",
        timezone: "America/Santiago",
        address_line: "Av. Siempre Viva 742",
        city: "Santiago",
        region: "Metropolitana"
      )
    end
  end

  def create_unit!(property:, status:)
    ActsAsTenant.with_tenant(@organization) do
      Unit.create!(
        organization: @organization,
        residential_property: property,
        identifier: "RP-CTRL-#{SecureRandom.hex(4)}",
        unit_type: UnitTypes::APARTMENT,
        status: status
      )
    end
  end
end
