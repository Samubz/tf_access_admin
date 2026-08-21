# frozen_string_literal: true

require "test_helper"

class Api::V1::Mobile::Auth::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:one)
    host! "example.com"
  end

  test "mobile login succeeds without a tenant subdomain for a global client user" do
    user = create_user_for_organization(
      organization: @organization,
      email: "mobile-client@example.com",
      role: AvailableRoles::CLIENT
    )

    post api_v1_mobile_auth_login_path, params: { email: user.email, password: "Password1@" }

    assert_response :ok
    assert response.headers["Authorization"].present?,
      "POST /api/v1/mobile/auth/login must dispatch a JWT"

    body = response.parsed_body
    assert_equal body.dig("data", "token"), response.headers["Authorization"].delete_prefix("Bearer ")
    assert_equal user.id, body.dig("data", "user", "id")
    assert_equal user.email, body.dig("data", "user", "email")
    assert_not body.dig("data", "user").key?("role"), "mobile login response must not include a role"
    assert_nil ActsAsTenant.current_tenant
  end

  test "mobile login rejects invalid credentials" do
    user = create_user_for_organization(
      organization: @organization,
      email: "mobile-wrong-password@example.com",
      role: AvailableRoles::CLIENT
    )

    post api_v1_mobile_auth_login_path, params: { email: user.email, password: "WrongPassword1@" }

    assert_response :unauthorized
  end

  test "mobile login rejects an unconfirmed account" do
    user = User.create!(
      email: "mobile-unconfirmed@example.com",
      password: "Password1@",
      password_confirmation: "Password1@",
      name: "Unconfirmed Client",
      dni: SecureRandom.hex(4),
      language: Languages::ES
    )
    ActsAsTenant.with_tenant(@organization) do
      Accounts::ProvisionTenantIdentity.call(user: user, organization: @organization)
    end

    post api_v1_mobile_auth_login_path, params: { email: user.email, password: "Password1@" }

    assert_response :unauthorized
  end

  test "mobile login rejects a deactivated account" do
    user = create_user_for_organization(
      organization: @organization,
      email: "mobile-deactivated@example.com",
      role: AvailableRoles::CLIENT
    )
    user.update!(deactivated_at: Time.current)

    post api_v1_mobile_auth_login_path, params: { email: user.email, password: "Password1@" }

    assert_response :unauthorized
  end

  test "mobile login rejects a user without the global client role" do
    user = create_confirmed_user(email: "mobile-non-client@example.com")

    post api_v1_mobile_auth_login_path, params: { email: user.email, password: "Password1@" }

    assert_response :forbidden
  end

  test "mobile logout revokes the token" do
    user = create_user_for_organization(
      organization: @organization,
      email: "mobile-logout@example.com",
      role: AvailableRoles::CLIENT
    )

    post api_v1_mobile_auth_login_path, params: { email: user.email, password: "Password1@" }
    token = response.parsed_body.dig("data", "token")

    delete api_v1_mobile_auth_logout_path, headers: { "Authorization" => "Bearer #{token}" }

    assert_response :no_content

    get api_v1_mobile_me_path, headers: { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }

    assert_response :unauthorized
  end

  test "mobile logout requires authentication" do
    delete api_v1_mobile_auth_logout_path, headers: { "Accept" => "application/json" }

    assert_response :unauthorized
  end
end
