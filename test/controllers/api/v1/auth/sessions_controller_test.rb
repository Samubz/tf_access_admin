# frozen_string_literal: true

require "test_helper"

class Api::V1::Auth::SessionsControllerTest < ActionDispatch::IntegrationTest
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
  end
end
