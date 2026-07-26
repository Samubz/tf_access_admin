# frozen_string_literal: true

require "test_helper"

class Users::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @user = create_user_for_organization(
      organization: @organization,
      email: "html-login@example.com",
      role: AvailableRoles::TENANT_ADMIN
    )

    host! "#{@organization.subdomain}.example.com"
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "html sign in does not dispatch a JWT Authorization header" do
    post user_session_path, params: {
      user: { email: @user.email, password: "Password1@" }
    }

    assert_redirected_to root_path
    assert_nil response.headers["Authorization"],
      "HTML sign-in should not dispatch a JWT; that is reserved for POST /api/v1/auth/login"
  end
end
