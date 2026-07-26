# frozen_string_literal: true

require "test_helper"

class Admin::OperationalRoles::AssignmentsControllerTest < ActionDispatch::IntegrationTest
  include InertiaTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "OR Assignments Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "or-asgn-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @staff_user = create_user_for_organization(
      organization: @organization,
      email: "or-asgn-staff@example.test",
      role: AvailableRoles::CLIENT
    )
    @staff_person = @staff_user.person_for(@organization)

    @client = create_user_for_organization(
      organization: @organization,
      email: "or-asgn-client@example.test",
      role: AvailableRoles::CLIENT
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  # ---------------------------------------------------------------------------
  # index
  # ---------------------------------------------------------------------------

  test "tenant_admin can list assignments" do
    sign_in_as @tenant_admin
    inertia_get admin_operational_roles_assignments_path

    assert_response :success
    assert_equal "admin/operational_roles/assignments/index", inertia_component
  end

  test "index returns assignments and roles in props" do
    sign_in_as @tenant_admin
    inertia_get admin_operational_roles_assignments_path

    props = inertia_props
    assert_includes props.keys, "assignments"
    assert_includes props.keys, "available_roles"
    assert_includes props.keys, "accessible_properties"
  end

  test "unprivileged client cannot list assignments" do
    sign_in_as @client
    inertia_get admin_operational_roles_assignments_path

    assert_response :redirect
  end

  # ---------------------------------------------------------------------------
  # create
  # ---------------------------------------------------------------------------

  test "tenant_admin can assign property_admin role" do
    sign_in_as @tenant_admin

    assert_difference -> { StaffAssignment.count } do
      post admin_operational_roles_assignments_path, params: {
        role: "property_admin",
        person_id: @staff_person.id,
        residential_property_id: @property.id
      }
    end

    assert_redirected_to admin_operational_roles_assignments_path
    assignment = StaffAssignment.last
    assert_equal StaffTypes::MANAGER, assignment.staff_type
    assert_equal StaffAssignment::STATUS_ACTIVE, assignment.status
  end

  test "tenant_admin can assign concierge role" do
    sign_in_as @tenant_admin

    assert_difference -> { StaffAssignment.count } do
      post admin_operational_roles_assignments_path, params: {
        role: "concierge",
        person_id: @staff_person.id,
        residential_property_id: @property.id
      }
    end

    assert_equal StaffTypes::CONCIERGE, StaffAssignment.last.staff_type
  end

  test "create with unknown role redirects without creating assignment" do
    sign_in_as @tenant_admin

    assert_no_difference -> { StaffAssignment.count } do
      post admin_operational_roles_assignments_path, params: {
        role: "invalid_role",
        person_id: @staff_person.id,
        residential_property_id: @property.id
      }
    end

    assert_redirected_to admin_operational_roles_assignments_path
  end

  test "unprivileged client cannot create assignment" do
    sign_in_as @client

    assert_no_difference -> { StaffAssignment.count } do
      post admin_operational_roles_assignments_path, params: {
        role: "concierge",
        person_id: @staff_person.id,
        residential_property_id: @property.id
      }
    end

    assert_response :redirect
  end

  # ---------------------------------------------------------------------------
  # destroy
  # ---------------------------------------------------------------------------

  test "tenant_admin can revoke an assignment" do
    assignment = StaffAssignment.create!(
      organization: @organization,
      person: @staff_person,
      residential_property: @property,
      staff_type: StaffTypes::CONCIERGE,
      status: StaffAssignment::STATUS_ACTIVE,
      starts_at: Date.current
    )

    sign_in_as @tenant_admin
    delete admin_operational_roles_assignment_path(assignment)

    assert_redirected_to admin_operational_roles_assignments_path
    assert_equal StaffAssignment::STATUS_INACTIVE, assignment.reload.status
  end

  test "unprivileged client cannot revoke an assignment" do
    assignment = StaffAssignment.create!(
      organization: @organization,
      person: @staff_person,
      residential_property: @property,
      staff_type: StaffTypes::CONCIERGE,
      status: StaffAssignment::STATUS_ACTIVE,
      starts_at: Date.current
    )

    sign_in_as @client
    delete admin_operational_roles_assignment_path(assignment)

    assert_response :redirect
    assert_equal StaffAssignment::STATUS_ACTIVE, assignment.reload.status
  end

  test "destroy with missing id redirects safely" do
    sign_in_as @tenant_admin
    delete admin_operational_roles_assignment_path(0)

    assert_redirected_to admin_operational_roles_assignments_path
  end

  private

  def sign_in_as(user)
    host! "#{@organization.subdomain}.example.com"
    post user_session_path, params: { user: { email: user.email, password: "Password1@" } }
  end
end
