# frozen_string_literal: true

require "test_helper"

class Admin::OperationalRolesControllerTest < ActionDispatch::IntegrationTest
  include InertiaTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "OR Controller Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "or-ctrl-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @client = create_user_for_organization(
      organization: @organization,
      email: "or-ctrl-client@example.test",
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

  test "tenant_admin can access operational roles index" do
    sign_in_as @tenant_admin
    inertia_get admin_operational_roles_path

    assert_response :success
    assert_equal "admin/operational_roles/index", inertia_component
  end

  test "index returns roles and summary in props" do
    sign_in_as @tenant_admin
    inertia_get admin_operational_roles_path

    props = inertia_props
    assert_includes props.keys, "roles"
    assert_includes props.keys, "summary"
    assert_includes props.keys, "capability_matrix"
  end

  test "index roles include user counts" do
    sign_in_as @tenant_admin
    inertia_get admin_operational_roles_path

    roles = inertia_props["roles"]
    assert roles.all? { |r| r.key?("users_count") }
  end

  test "unprivileged client cannot access operational roles index" do
    sign_in_as @client
    inertia_get admin_operational_roles_path

    assert_response :redirect
  end

  # ---------------------------------------------------------------------------
  # show
  # ---------------------------------------------------------------------------

  test "tenant_admin can view role detail" do
    sign_in_as @tenant_admin
    inertia_get admin_operational_role_path("property_admin")

    assert_response :success
    assert_equal "admin/operational_roles/show", inertia_component
  end

  test "show includes role, users and capability_groups in props" do
    sign_in_as @tenant_admin
    inertia_get admin_operational_role_path("concierge")

    props = inertia_props
    assert_includes props.keys, "role"
    assert_includes props.keys, "users"
    assert_includes props.keys, "capability_groups"
  end

  test "show role props include capabilities list" do
    sign_in_as @tenant_admin
    inertia_get admin_operational_role_path("property_admin")

    role = inertia_props["role"]
    assert_includes role.keys, "capabilities"
    assert_includes role["capabilities"], "manage_property"
  end

  test "show redirects for unknown role key" do
    sign_in_as @tenant_admin
    get admin_operational_role_path("nonexistent_role")

    assert_redirected_to admin_operational_roles_path
  end

  test "unprivileged client cannot view role detail" do
    sign_in_as @client
    inertia_get admin_operational_role_path("property_admin")

    assert_response :redirect
  end

  private

  def sign_in_as(user)
    host! "#{@organization.subdomain}.example.com"
    post user_session_path, params: { user: { email: user.email, password: "Password1@" } }
  end
end
