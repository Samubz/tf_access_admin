# frozen_string_literal: true

require "test_helper"

class Api::V1::Mobile::OrganizationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @organization = organizations(:one)
    @user = create_user_for_organization(
      organization: @organization,
      email: "mobile-org-detail@example.com",
      role: AvailableRoles::CLIENT
    )
  end

  test "member fetches organization detail" do
    sign_in @user

    get api_v1_mobile_organization_path(@organization.id)

    assert_response :ok
    body = response.parsed_body
    assert_equal @organization.name, body.dig("data", "name")
    assert_nil body.dig("data", "cover")
    assert_nil body.dig("data", "logo")
    assert_equal [], body.dig("data", "residential_properties")
  end

  test "non-member is rejected with not found" do
    other_organization = organizations(:two)
    sign_in @user

    get api_v1_mobile_organization_path(other_organization.id)

    assert_response :not_found
  end

  test "nonexistent organization id is rejected with not found" do
    sign_in @user

    get api_v1_mobile_organization_path(SecureRandom.uuid)

    assert_response :not_found
  end

  test "unauthenticated request is rejected" do
    get api_v1_mobile_organization_path(@organization.id), headers: { "Accept" => "application/json" }

    assert_response :unauthorized
  end
end
