# frozen_string_literal: true

require "test_helper"

class Api::V1::Mobile::MeControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @organization = organizations(:one)
    @user = create_user_for_organization(
      organization: @organization,
      email: "mobile-me@example.com",
      role: AvailableRoles::CLIENT
    )
  end

  test "authenticated user fetches their profile" do
    sign_in @user

    get api_v1_mobile_me_path

    assert_response :ok
    body = response.parsed_body
    assert_equal @user.email, body.dig("data", "email")
    assert_equal @user.name, body.dig("data", "name")
    assert_equal @user.dni, body.dig("data", "dni")
    assert_equal(
      [ { "id" => @organization.id, "name" => @organization.name, "logo" => nil, "units_count" => 0 } ],
      body.dig("data", "organizations")
    )
    refute body["data"].key?("role")
  end

  test "profile includes an organization for each active membership" do
    other_organization = organizations(:two)
    ActsAsTenant.with_tenant(other_organization) do
      Accounts::ProvisionTenantIdentity.call(user: @user, organization: other_organization)
    end

    sign_in @user

    get api_v1_mobile_me_path

    assert_response :ok
    org_ids = response.parsed_body.dig("data", "organizations").map { |o| o["id"] }
    assert_equal [ @organization.id, other_organization.id ].sort, org_ids.sort
  end

  test "profile returns no organizations when membership is revoked" do
    person = ActsAsTenant.with_tenant(@organization) { @user.person_for(@organization) }
    person.organization_membership.update!(status: OrganizationMembership::STATUS_REVOKED)

    sign_in @user

    get api_v1_mobile_me_path

    assert_response :ok
    assert_equal [], response.parsed_body.dig("data", "organizations")
  end

  test "unauthenticated request is rejected" do
    get api_v1_mobile_me_path, headers: { "Accept" => "application/json" }

    assert_response :unauthorized
  end
end
