# frozen_string_literal: true

require "test_helper"

# GET /api/v1/private/units/:unit_id/visits?day=YYYY-MM-DD
# mobile-private-api "Unit visits by day".
class Api::V1::Private::Units::VisitsIndexControllerTest < ActionDispatch::IntegrationTest
  include OperationalPolicyTestHelper
  include Devise::Test::IntegrationHelpers

  setup do
    @organization = organizations(:one)
    @other_org    = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property = create_property(@organization, "Visits Index Property")
    @unit     = create_unit(@property, "VI-101")

    @resident = create_user_for_organization(
      organization: @organization,
      email: "visits-index-resident@example.test",
      role: AvailableRoles::CLIENT
    )
    UnitOccupancy.create!(
      organization: @organization,
      person: @resident.person_for(@organization),
      unit: @unit,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: 7.days.ago,
      status: OccupancyStatuses::ACTIVE,
      can_authorize_visits: true
    )

    @stranger = create_user_for_organization(
      organization: @organization,
      email: "visits-index-stranger@example.test",
      role: AvailableRoles::CLIENT
    )

    @visitor = Person.create!(
      organization: @organization,
      display_name: "Index Visitor",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )

    tz = ActiveSupport::TimeZone["America/Santiago"]
    # Two on 2026-09-20 (edges of the day in property tz), one on 2026-09-21
    @visit_early = create_visit(tz.parse("2026-09-20 00:30"))
    @visit_late  = create_visit(tz.parse("2026-09-20 23:30"))
    @visit_next  = create_visit(tz.parse("2026-09-21 01:00"))
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "resident lists exactly the visits of the requested day" do
    get_visits(@resident, @unit, day: "2026-09-20")

    assert_response :ok
    data = JSON.parse(response.body).fetch("data")
    assert_equal [ @visit_early.id, @visit_late.id ], data.map { |v| v["id"] }

    first = data.first
    assert_equal "Index Visitor", first["visitor_name"]
    assert_equal VisitStatuses::AUTHORIZED, first["status"]
    assert_equal @visit_early.scheduled_at.to_i, Time.iso8601(first["scheduled_at"]).to_i
    assert_nil first["checked_in_at"]
    assert_nil first["checked_out_at"]
  end

  test "invalid day returns 422 with localized error" do
    get_visits(@resident, @unit, day: "2026-13-40")

    assert_response :unprocessable_entity
    assert_equal I18n.t("api.errors.invalid_day"), JSON.parse(response.body)["error"]
  end

  test "missing day returns 422" do
    get_visits(@resident, @unit, day: nil)

    assert_response :unprocessable_entity
  end

  test "without token returns 401" do
    host! "#{@organization.subdomain}.example.com"
    get api_v1_private_unit_visits_path(unit_id: @unit.id, day: "2026-09-20"), headers: { "Accept" => "application/json" }

    assert_response :unauthorized
  end

  test "member without relationship to the unit returns 403" do
    get_visits(@stranger, @unit, day: "2026-09-20")

    assert_response :forbidden
    assert_equal I18n.t("api.visits.authorization_denied"), JSON.parse(response.body)["error"]
  end

  test "unit from another organization returns 404" do
    other_unit = ActsAsTenant.with_tenant(@other_org) do
      create_unit(create_property(@other_org, "Other Org Property"), "OO-1")
    end

    get_visits(@resident, other_unit, day: "2026-09-20")

    assert_response :not_found
  end

  private

  def create_visit(scheduled_at)
    Visit.create!(
      organization: @organization,
      unit: @unit,
      visitor_person: @visitor,
      scheduled_at: scheduled_at,
      status: VisitStatuses::AUTHORIZED,
      created_by: @resident,
      authorized_by: @resident
    )
  end

  def get_visits(user, unit, day:)
    host! "#{@organization.subdomain}.example.com"
    sign_in user
    get api_v1_private_unit_visits_path(unit_id: unit.id), params: { day: day }.compact
    sign_out user
  end
end
