# frozen_string_literal: true

require "test_helper"

class Api::V1::Mobile::Auth::PasswordsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @organization = organizations(:one)
    host! "example.com"
    @user = create_user_for_organization(
      organization: @organization,
      email: "mobile-password@example.com",
      role: AvailableRoles::CLIENT
    )
    @token = login_and_get_token(@user, "Password1@")
  end

  test "successful password change returns a new token and updates the password" do
    patch api_v1_mobile_auth_password_path,
      params: { current_password: "Password1@", password: "NewPassword1@", password_confirmation: "NewPassword1@" },
      headers: auth_headers(@token)

    assert_response :ok
    body = response.parsed_body
    new_token = body.dig("data", "token")
    assert new_token.present?
    assert_not_equal @token, new_token
    assert_equal @user.id, body.dig("data", "user", "id")
    assert_equal @user.email, body.dig("data", "user", "email")

    @user.reload
    assert @user.valid_password?("NewPassword1@")
    assert @user.password_changed_at.present?
  end

  test "the newly issued token authenticates immediately" do
    patch api_v1_mobile_auth_password_path,
      params: { current_password: "Password1@", password: "NewPassword1@", password_confirmation: "NewPassword1@" },
      headers: auth_headers(@token)
    new_token = response.parsed_body.dig("data", "token")

    get api_v1_mobile_me_path, headers: auth_headers(new_token)

    assert_response :ok
  end

  test "the token used before the password change is rejected afterward" do
    # JWT `iat` only has whole-second resolution (Warden::JWTAuth::TokenEncoder
    # uses Time.now.to_i), so the revocation check compares whole seconds too.
    # Travel forward to guarantee the old token's `iat` lands in a strictly
    # earlier second than `password_changed_at`.
    travel 1.second do
      patch api_v1_mobile_auth_password_path,
        params: { current_password: "Password1@", password: "NewPassword1@", password_confirmation: "NewPassword1@" },
        headers: auth_headers(@token)
      assert_response :ok
    end

    get api_v1_mobile_me_path, headers: auth_headers(@token)

    assert_response :unauthorized
  end

  test "rejects an incorrect current password" do
    patch api_v1_mobile_auth_password_path,
      params: { current_password: "WrongPassword1@", password: "NewPassword1@", password_confirmation: "NewPassword1@" },
      headers: auth_headers(@token)

    assert_response :unprocessable_entity
    @user.reload
    assert @user.valid_password?("Password1@")
  end

  test "rejects a mismatched confirmation" do
    patch api_v1_mobile_auth_password_path,
      params: { current_password: "Password1@", password: "NewPassword1@", password_confirmation: "SomethingElse1@" },
      headers: auth_headers(@token)

    assert_response :unprocessable_entity
    @user.reload
    assert @user.valid_password?("Password1@")
  end

  test "rejects a new password that fails the complexity rule" do
    patch api_v1_mobile_auth_password_path,
      params: { current_password: "Password1@", password: "weakpassword", password_confirmation: "weakpassword" },
      headers: auth_headers(@token)

    assert_response :unprocessable_entity
    @user.reload
    assert @user.valid_password?("Password1@")
  end

  test "requires authentication" do
    patch api_v1_mobile_auth_password_path,
      params: { current_password: "Password1@", password: "NewPassword1@", password_confirmation: "NewPassword1@" },
      headers: { "Accept" => "application/json" }

    assert_response :unauthorized
  end

  private

  def login_and_get_token(user, password)
    post api_v1_mobile_auth_login_path, params: { email: user.email, password: password }
    response.parsed_body.dig("data", "token")
  end

  def auth_headers(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end
end
