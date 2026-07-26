# frozen_string_literal: true

require "test_helper"

class Admin::Visits::CheckInsControllerTest < ActionDispatch::IntegrationTest
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property = create_property(@organization, "CheckIn Ctrl Property")
    @other_property = create_property(@organization, "CheckIn Ctrl Property Q")
    @unit = create_unit(@property, "CI-P-101")

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "checkin-ctrl-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @concierge = create_staff_user(
      organization: @organization,
      email: "checkin-ctrl-concierge@example.test",
      staff_type: StaffTypes::CONCIERGE,
      property: @property
    )
    @concierge_q = create_staff_user(
      organization: @organization,
      email: "checkin-ctrl-concierge-q@example.test",
      staff_type: StaffTypes::CONCIERGE,
      property: @other_property
    )
    @owner = create_owner_user(
      organization: @organization,
      email: "checkin-ctrl-owner@example.test",
      unit: @unit
    )

    visitor = Person.create!(
      organization: @organization,
      display_name: "CheckIn Ctrl Visitor",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )

    @visit = ActsAsTenant.with_tenant(@organization) do
      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: visitor,
        scheduled_at: 1.hour.from_now,
        valid_from: 30.minutes.ago,
        status: VisitStatuses::AUTHORIZED,
        authorized_at: 10.minutes.ago,
        authorized_by_id: @tenant_admin.id
      )
    end
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "tenant_admin can check in an authorized visit" do
    sign_in_as(@tenant_admin)
    post admin_visit_check_ins_path(@visit), params: {
      check_in: { access_point: "main_entrance", notes: "On time" }
    }
    assert_response :redirect
    assert_equal VisitStatuses::CHECKED_IN, @visit.reload.status
  end

  test "concierge of property can check in an authorized visit" do
    sign_in_as(@concierge)
    post admin_visit_check_ins_path(@visit), params: {
      check_in: { access_point: "main_entrance" }
    }
    assert_response :redirect
    assert_equal VisitStatuses::CHECKED_IN, @visit.reload.status
  end

  test "concierge of another property cannot check in (cross-property, 6.8)" do
    sign_in_as(@concierge_q)
    post admin_visit_check_ins_path(@visit), params: {
      check_in: { access_point: "main_entrance" }
    }
    assert_response :redirect
    assert_equal VisitStatuses::AUTHORIZED, @visit.reload.status
  end

  test "check_in on already checked-in visit returns redirect with error (invalid transition)" do
    @visit.update_columns(
      status: VisitStatuses::CHECKED_IN,
      checked_in_at: Time.current,
      checked_in_by_id: @tenant_admin.id
    )
    sign_in_as(@tenant_admin)
    post admin_visit_check_ins_path(@visit), params: {
      check_in: {}
    }
    assert_response :redirect
    assert_equal VisitStatuses::CHECKED_IN, @visit.reload.status
  end

  private

  def sign_in_as(user)
    host! "#{@organization.subdomain}.example.com"
    post user_session_path, params: { user: { email: user.email, password: "Password1@" } }
  end
end
