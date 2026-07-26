# frozen_string_literal: true

require "test_helper"

class Api::V1::Private::DeviceTokensControllerTest < ActionDispatch::IntegrationTest
  include OperationalPolicyTestHelper
  include Devise::Test::IntegrationHelpers

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @user = create_user_for_organization(
      organization: @organization,
      email: "device-token-controller-user@example.test",
      role: AvailableRoles::CLIENT
    )
    @other_user = create_user_for_organization(
      organization: @organization,
      email: "device-token-controller-other@example.test",
      role: AvailableRoles::CLIENT
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "authenticated user registers a device token" do
    host! "#{@organization.subdomain}.example.com"
    sign_in @user

    post api_v1_private_device_token_path,
         params: { device_token: { token: "tok-1", platform: "ios" } }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :created
    assert_equal "tok-1", @user.reload.device_token.token
  end

  test "registering again replaces the previous token for the same user" do
    host! "#{@organization.subdomain}.example.com"
    sign_in @user
    DeviceToken.create!(user: @user, token: "old-token", platform: "ios")

    post api_v1_private_device_token_path,
         params: { device_token: { token: "new-token", platform: "android" } }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :created
    assert_equal "new-token", @user.reload.device_token.token
    assert_equal 1, DeviceToken.where(user: @user).count
  end

  test "unauthenticated registration is rejected" do
    host! "#{@organization.subdomain}.example.com"

    post api_v1_private_device_token_path,
         params: { device_token: { token: "tok-1", platform: "ios" } }.to_json,
         headers: { "Content-Type" => "application/json", "Accept" => "application/json" }

    assert_response :unauthorized
  end

  test "user can destroy their own device token" do
    host! "#{@organization.subdomain}.example.com"
    sign_in @user
    DeviceToken.create!(user: @user, token: "tok-1", platform: "ios")

    delete api_v1_private_device_token_path

    assert_response :no_content
    assert_nil @user.reload.device_token
  end

  test "destroy never touches another user's device token" do
    host! "#{@organization.subdomain}.example.com"
    other_token = DeviceToken.create!(user: @other_user, token: "other-tok", platform: "ios")
    sign_in @user

    delete api_v1_private_device_token_path

    assert_response :no_content
    assert DeviceToken.exists?(other_token.id)
  end
end
