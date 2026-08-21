# frozen_string_literal: true

require "test_helper"

class Api::V1::Mobile::ResidentialProperties::Units::VisitsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @organization = organizations(:one)
    @user = create_user_for_organization(
      organization: @organization,
      email: "mobile-visits@example.com",
      role: AvailableRoles::CLIENT
    )
    @person = ActsAsTenant.with_tenant(@organization) { @user.person_for(@organization) }
    @property = create_property!(status: PropertyStatuses::ACTIVE)
    @unit = create_unit!(property: @property, status: UnitStatuses::AVAILABLE)
  end

  test "resident fetches today's visits" do
    occupy_unit!
    zone = ActiveSupport::TimeZone[@property.timezone]
    visit = create_visit!(scheduled_at: zone.now.change(hour: 12))
    sign_in @user

    get api_v1_mobile_residential_property_unit_visits_path(id: @property.id, unit_id: @unit.id)

    assert_response :ok
    body = response.parsed_body
    assert_equal 1, body["data"].size
    assert_equal visit.visitor_person.display_name, body["data"].first["visitor_name"]
    assert_equal visit.status, body["data"].first["status"]
  end

  test "returns empty array when no visits scheduled that day" do
    occupy_unit!
    sign_in @user

    get api_v1_mobile_residential_property_unit_visits_path(id: @property.id, unit_id: @unit.id)

    assert_response :ok
    assert_equal [], response.parsed_body["data"]
  end

  test "malformed day is rejected with unprocessable entity" do
    occupy_unit!
    sign_in @user

    get api_v1_mobile_residential_property_unit_visits_path(id: @property.id, unit_id: @unit.id), params: { day: "not-a-date" }

    assert_response :unprocessable_entity
  end

  test "owner without active occupancy is rejected with not found" do
    own_unit!
    sign_in @user

    get api_v1_mobile_residential_property_unit_visits_path(id: @property.id, unit_id: @unit.id)

    assert_response :not_found
  end

  test "nonexistent residential property id is rejected with not found" do
    sign_in @user

    get api_v1_mobile_residential_property_unit_visits_path(id: SecureRandom.uuid, unit_id: @unit.id)

    assert_response :not_found
  end

  test "nonexistent unit id is rejected with not found" do
    occupy_unit!
    sign_in @user

    get api_v1_mobile_residential_property_unit_visits_path(id: @property.id, unit_id: SecureRandom.uuid)

    assert_response :not_found
  end

  test "non-active residential property is rejected with not found" do
    inactive_property = create_property!(status: PropertyStatuses::INACTIVE)
    unit = create_unit!(property: inactive_property, status: UnitStatuses::AVAILABLE)
    ActsAsTenant.with_tenant(@organization) do
      UnitOccupancy.create!(
        organization: @organization, unit: unit, person: @person,
        occupancy_type: OccupancyTypes::TENANT, status: OccupancyStatuses::ACTIVE, starts_at: Time.current
      )
    end
    sign_in @user

    get api_v1_mobile_residential_property_unit_visits_path(id: inactive_property.id, unit_id: unit.id)

    assert_response :not_found
  end

  test "ineligible unit status is rejected with not found" do
    occupy_unit!
    @unit.update!(status: UnitStatuses::MAINTENANCE)
    sign_in @user

    get api_v1_mobile_residential_property_unit_visits_path(id: @property.id, unit_id: @unit.id)

    assert_response :not_found
  end

  test "unauthenticated request is rejected" do
    get api_v1_mobile_residential_property_unit_visits_path(id: @property.id, unit_id: @unit.id),
      headers: { "Accept" => "application/json" }

    assert_response :unauthorized
  end

  private

  def own_unit!
    ActsAsTenant.with_tenant(@organization) do
      UnitOwnership.create!(
        organization: @organization, unit: @unit, person: @person,
        ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
      )
    end
  end

  def occupy_unit!
    ActsAsTenant.with_tenant(@organization) do
      UnitOccupancy.create!(
        organization: @organization, unit: @unit, person: @person,
        occupancy_type: OccupancyTypes::TENANT, status: OccupancyStatuses::ACTIVE, starts_at: Time.current
      )
    end
  end

  def create_visit!(scheduled_at:)
    ActsAsTenant.with_tenant(@organization) do
      visitor = Person.create!(
        organization: @organization,
        display_name: "Visitor #{SecureRandom.hex(4)}",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: visitor,
        scheduled_at: scheduled_at,
        valid_from: scheduled_at,
        status: VisitStatuses::PENDING,
        visit_type: VisitTypes::GUEST
      )
    end
  end

  def create_property!(status:)
    ActsAsTenant.with_tenant(@organization) do
      ResidentialProperty.create!(
        organization: @organization,
        name: "RP Visits Ctrl Test #{SecureRandom.hex(4)}",
        property_type: PropertyTypes::BUILDING,
        status: status,
        country: "Chile",
        timezone: "America/Santiago"
      )
    end
  end

  def create_unit!(property:, status:)
    ActsAsTenant.with_tenant(@organization) do
      Unit.create!(
        organization: @organization,
        residential_property: property,
        identifier: "RP-VISITS-CTRL-#{SecureRandom.hex(4)}",
        unit_type: UnitTypes::APARTMENT,
        status: status
      )
    end
  end
end
