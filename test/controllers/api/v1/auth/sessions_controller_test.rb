# frozen_string_literal: true

require "test_helper"

class Api::V1::Auth::SessionsControllerTest < ActionDispatch::IntegrationTest
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @user = create_user_for_organization(
      organization: @organization,
      email: "api-login@example.com",
      role: AvailableRoles::TENANT_ADMIN
    )

    host! "#{@organization.subdomain}.example.com"
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "api login dispatches a JWT Authorization header" do
    post api_v1_auth_login_path, params: { email: @user.email, password: "Password1@" }

    assert_response :ok
    assert response.headers["Authorization"].present?,
      "POST /api/v1/auth/login must still dispatch a JWT"

    body = response.parsed_body
    assert_equal body.dig("data", "token"), response.headers["Authorization"].delete_prefix("Bearer ")
    assert_equal "tenant_admin", body.dig("data", "user", "role")
  end

  test "resident without organizational role logs in with role resident" do
    resident = create_user_for_organization(
      organization: @organization,
      email: "api-resident@example.com",
      role: AvailableRoles::CLIENT
    )
    property = create_property(@organization, "Login Property")
    unit = create_unit(property, "L-101")
    UnitOccupancy.create!(
      organization: @organization,
      person: resident.person_for(@organization),
      unit: unit,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: 7.days.ago,
      status: OccupancyStatuses::ACTIVE,
      can_authorize_visits: true
    )

    post api_v1_auth_login_path, params: { email: resident.email, password: "Password1@" }

    assert_response :ok
    assert response.parsed_body.dig("data", "token").present?
    assert_equal "resident", response.parsed_body.dig("data", "user", "role")
  end

  test "user who is not a member of the tenant is rejected without a token" do
    other_org = organizations(:two)
    outsider = create_user_for_organization(
      organization: other_org,
      email: "api-outsider@example.com",
      role: AvailableRoles::CLIENT
    )

    post api_v1_auth_login_path, params: { email: outsider.email, password: "Password1@" }

    assert_response :unauthorized
    assert_nil response.parsed_body.dig("data", "token")
    assert_nil response.headers["Authorization"]
  end

  test "unconfirmed member is rejected" do
    member = create_user_for_organization(
      organization: @organization,
      email: "api-unconfirmed@example.com",
      role: AvailableRoles::CLIENT
    )
    member.update_columns(confirmed_at: nil)

    post api_v1_auth_login_path, params: { email: member.email, password: "Password1@" }

    assert_response :unauthorized
    assert_equal I18n.t("api.errors.unconfirmed_account"), response.parsed_body["error"]
  end
end
