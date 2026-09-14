# frozen_string_literal: true

require "test_helper"

# GET/PATCH /api/v1/private/me — mobile-private-api "Profile endpoint".
class Api::V1::Private::ProfilesControllerTest < ActionDispatch::IntegrationTest
  include OperationalPolicyTestHelper
  include Devise::Test::IntegrationHelpers

  setup do
    @organization = organizations(:one)
    @other_org    = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property = create_property(@organization, "Profile API Property")
    @unit_a   = create_unit(@property, "PR-101")
    @unit_b   = create_unit(@property, "PR-102")

    @resident = create_user_for_organization(
      organization: @organization,
      email: "profile-api-resident@example.test",
      role: AvailableRoles::CLIENT,
      name: "Profile Resident"
    )
    @person = @resident.person_for(@organization)
    @person.contact_phone = "+56 912345678"
    @person.birthdate = Date.new(1990, 5, 20)
    @person.save!

    UnitOccupancy.create!(
      organization: @organization, person: @person, unit: @unit_a,
      occupancy_type: OccupancyTypes::TENANT, starts_at: 7.days.ago,
      status: OccupancyStatuses::ACTIVE, can_authorize_visits: true
    )
    UnitOwnership.create!(
      organization: @organization, person: @person, unit: @unit_b,
      ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "GET /me returns the profile from the current tenant's person" do
    get_me(@resident)

    assert_response :ok
    data = JSON.parse(response.body).fetch("data")
    assert_equal @resident.email, data["email"]
    assert_equal "Profile Resident", data["name"]
    assert_equal @resident.dni, data["dni"]
    assert_equal({ "countryCode" => "+56", "number" => "912345678" }, data["phone"])
    assert_equal "1990-05-20", data["dateOfBirth"]
    assert_nil data["gender"]
    assert_nil data["avatarUrl"]
    assert_equal "resident", data["role"]

    orgs = data.fetch("organizations")
    assert_equal [ @organization.id ], orgs.map { |o| o["id"] }
    assert_equal @organization.name, orgs.first["name"]
    assert_nil orgs.first["logo"]
    assert_equal 2, orgs.first["units_count"]
  end

  test "GET /me returns null phone and dateOfBirth when the person has none" do
    @person.contact_phone = nil
    @person.birthdate = nil
    @person.metadata = @person.metadata.except("phone")
    @person.save!

    get_me(@resident)

    assert_response :ok
    data = JSON.parse(response.body).fetch("data")
    assert_nil data["phone"]
    assert_nil data["dateOfBirth"]
  end

  test "GET /me without token returns 401" do
    host! "#{@organization.subdomain}.example.com"
    get api_v1_private_me_path, headers: { "Accept" => "application/json" }

    assert_response :unauthorized
  end

  test "GET /me for a non-member of the tenant returns 403" do
    outsider = create_user_for_organization(
      organization: @other_org,
      email: "profile-api-outsider@example.test",
      role: AvailableRoles::CLIENT
    )

    get_me(outsider)

    assert_response :forbidden
  end

  test "PATCH /me persists name, phone, dateOfBirth and avatar" do
    host! "#{@organization.subdomain}.example.com"
    sign_in @resident

    patch api_v1_private_me_path, params: {
      name: "Renamed Resident",
      phone: { countryCode: "+54", number: "1122334455" },
      dateOfBirth: "1991-01-02",
      gender: "female",
      avatar: fixture_file_upload("avatar.png", "image/png")
    }

    assert_response :ok
    data = JSON.parse(response.body).fetch("data")
    assert_equal "Renamed Resident", data["name"]
    assert_equal({ "countryCode" => "+54", "number" => "1122334455" }, data["phone"])
    assert_equal "1991-01-02", data["dateOfBirth"]
    assert_nil data["gender"]
    assert_not_nil data["avatarUrl"]

    assert_equal "Renamed Resident", @resident.reload.name
    assert @resident.avatar.attached?
    # Person.find: contact_phone memoizes the value assigned in setup, so reload is not enough.
    person = Person.find(@person.id)
    assert_equal "+54 1122334455", person.contact_phone
    assert_equal Date.new(1991, 1, 2), person.birthdate
  end

  test "PATCH /me with null phone clears the person's phone" do
    host! "#{@organization.subdomain}.example.com"
    sign_in @resident

    patch api_v1_private_me_path,
          params: { phone: nil }.to_json,
          headers: { "Content-Type" => "application/json" }

    assert_response :ok
    assert_nil JSON.parse(response.body).dig("data", "phone")
    assert_nil Person.find(@person.id).contact_phone
  end

  test "PATCH /me without token returns 401" do
    host! "#{@organization.subdomain}.example.com"
    patch api_v1_private_me_path, params: { name: "X" }, headers: { "Accept" => "application/json" }

    assert_response :unauthorized
  end

  private

  def get_me(user)
    host! "#{@organization.subdomain}.example.com"
    sign_in user
    get api_v1_private_me_path, headers: { "Accept" => "application/json" }
    sign_out user
  end
end
