# frozen_string_literal: true

require "test_helper"

# GET /api/v1/private/invitations
# mobile-private-api "Visitor invitations endpoint" (D2).
class Api::V1::Private::InvitationsControllerTest < ActionDispatch::IntegrationTest
  include OperationalPolicyTestHelper
  include Devise::Test::IntegrationHelpers

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property = create_property(@organization, "Invitations Property")
    @unit     = create_unit(@property, "INV-101")

    @host = create_user_for_organization(
      organization: @organization,
      email: "invitations-host@example.test",
      role: AvailableRoles::CLIENT,
      name: "Host Person"
    )
    @host_person = @host.person_for(@organization)
    @host_person.update!(contact_phone: "+56911112222", document_number: "11.111.111-1")

    @visitor = create_user_for_organization(
      organization: @organization,
      email: "invitations-visitor@example.test",
      role: AvailableRoles::VISITOR,
      name: "Visitor Person"
    )
    @visitor_person = @visitor.person_for(@organization)

    @other_visitor = create_user_for_organization(
      organization: @organization,
      email: "invitations-other-visitor@example.test",
      role: AvailableRoles::VISITOR
    )
    @other_person = @other_visitor.person_for(@organization)

    @member = create_user_for_organization(
      organization: @organization,
      email: "invitations-member@example.test",
      role: AvailableRoles::CLIENT
    )

    @tomorrow   = create_visit(@visitor_person, 1.day.from_now)
    @later      = create_visit(@visitor_person, 3.days.from_now)
    @today      = create_visit(@visitor_person, Time.zone.now.beginning_of_day + 1.minute)
    @last_week  = create_visit(@visitor_person, 7.days.ago)
    @cancelled  = create_visit(@visitor_person, 2.days.from_now, status: VisitStatuses::CANCELLED)
    @others     = create_visit(@other_person, 1.day.from_now)
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "visitor sees only own upcoming, non-cancelled invitations ordered by date" do
    get_invitations(@visitor)

    assert_response :ok
    data = JSON.parse(response.body).fetch("data")
    assert_equal [ @today.id, @tomorrow.id, @later.id ], data.map { |v| v["id"] }
  end

  test "each item carries the expected shape and no other person's PII" do
    get_invitations(@visitor)

    item = JSON.parse(response.body).fetch("data").first
    assert_equal %w[id status scheduled_at residential_property_name unit_identifier host_name access_code].sort,
                 item.keys.sort
    assert_equal VisitStatuses::AUTHORIZED, item["status"]
    assert_equal "Invitations Property", item["residential_property_name"]
    assert_equal "INV-101", item["unit_identifier"]
    assert_equal "Host Person", item["host_name"]
    assert_nil item["access_code"]

    body = response.body
    refute_includes body, "invitations-host@example.test"
    refute_includes body, "+56911112222"
    refute_includes body, "11.111.111-1"
  end

  test "member without view_own_visits returns 403" do
    get_invitations(@member)

    assert_response :forbidden
    assert_equal I18n.t("api.errors.forbidden"), JSON.parse(response.body)["error"]
  end

  test "without session returns 401" do
    host! "#{@organization.subdomain}.example.com"
    get api_v1_private_invitations_path, headers: { "Accept" => "application/json" }

    assert_response :unauthorized
  end

  private

  def create_visit(visitor_person, scheduled_at, status: VisitStatuses::AUTHORIZED)
    Visit.create!(
      organization: @organization,
      unit: @unit,
      visitor_person: visitor_person,
      scheduled_at: scheduled_at,
      status: status,
      created_by: @host,
      authorized_by: @host
    )
  end

  def get_invitations(user)
    host! "#{@organization.subdomain}.example.com"
    sign_in user
    get api_v1_private_invitations_path, headers: { "Accept" => "application/json" }
    sign_out user
  end
end
