# frozen_string_literal: true

require "test_helper"

class Admin::ResidentialPropertiesControllerTest < ActionDispatch::IntegrationTest
  include InertiaTestHelper
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property = create_property(@organization, "Controller Property P")
    @other_property = create_property(@organization, "Controller Property Q")

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "rp-ctrl-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @property_admin = create_staff_user(
      organization: @organization,
      email: "rp-ctrl-admin-prop@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )
    @client = create_user_for_organization(
      organization: @organization,
      email: "rp-ctrl-client@example.test",
      role: AvailableRoles::CLIENT
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "tenant_admin create redirects to wizard" do
    sign_in_as @tenant_admin

    post admin_residential_properties_path, params: {
      residential_property: valid_property_params(name: "Controller Created Property")
    }

    assert_redirected_to admin_property_setup_new_wizard_path
  end

  test "create redirects to wizard instead of showing field errors" do
    sign_in_as @tenant_admin

    post admin_residential_properties_path, params: {
      residential_property: valid_property_params(name: @property.name)
    }

    assert_redirected_to admin_property_setup_new_wizard_path
  end

  test "property_admin cannot create properties" do
    sign_in_as @property_admin

    assert_no_difference -> { ResidentialProperty.count } do
      post admin_residential_properties_path, params: {
        residential_property: valid_property_params(name: "Denied Create Property")
      }
    end

    assert_response :redirect
  end

  test "tenant_admin archive delegates to Properties::Archive" do
    sign_in_as @tenant_admin

    post archive_admin_residential_property_path(@property)

    assert_redirected_to admin_residential_properties_path
    assert_equal PropertyStatuses::ARCHIVED, @property.reload.status
    assert ResidentialProperty.exists?(@property.id)
  end

  test "property_admin cannot archive properties" do
    sign_in_as @property_admin

    post archive_admin_residential_property_path(@property)

    assert_response :redirect
    assert_equal PropertyStatuses::ACTIVE, @property.reload.status
  end

  test "index exposes backend-driven permissions in serializer props" do
    sign_in_as @tenant_admin
    inertia_get admin_residential_properties_path

    assert_response :success
    row = inertia_props["residential_properties"].find { |property| property["id"] == @property.id }
    assert row["permissions"]["archive"]
    assert_includes row["actions"], "archive"
  end

  test "show exposes detail props scoped to the property" do
    sign_in_as @tenant_admin
    inertia_get admin_residential_property_path(@property)

    assert_response :success
    assert_equal @property.id, inertia_props["residential_property"]["property"]["id"]
    assert_includes inertia_props["residential_property"], "preview"
    assert_includes inertia_props["residential_property"], "permissions"
    assert_includes inertia_props["residential_property"], "next_actions"
  end

  test "show denies cross-organization access" do
    sign_in_as @tenant_admin
    other_org_property = ActsAsTenant.with_tenant(@other_organization) do
      create_property(@other_organization, "Other Org Detail Property")
    end

    inertia_get admin_residential_property_path(other_org_property)

    assert_redirected_to admin_residential_properties_path
  end

  test "show hides primary edit permission for configured/active properties" do
    sign_in_as @tenant_admin
    inertia_get admin_residential_property_path(@property)

    assert_response :success
    refute inertia_props["residential_property"]["permissions"]["edit"]
  end

  test "show exposes primary edit permission for draft/created properties" do
    sign_in_as @tenant_admin
    @property.update!(status: PropertyStatuses::CREATED)

    inertia_get admin_residential_property_path(@property)

    assert_response :success
    assert inertia_props["residential_property"]["permissions"]["edit"]
  end

  test "record loading uses policy scope" do
    sign_in_as @tenant_admin
    other_org_property = ActsAsTenant.with_tenant(@other_organization) do
      create_property(@other_organization, "Other Org Controller Property")
    end

    post archive_admin_residential_property_path(other_org_property)

    assert_redirected_to admin_residential_properties_path
    assert_equal PropertyStatuses::ACTIVE, other_org_property.reload.status
  end

  private

  def sign_in_as(user)
    host! "#{@organization.subdomain}.example.com"
    post user_session_path, params: { user: { email: user.email, password: "Password1@" } }
  end

  def valid_property_params(name:)
    {
      name: name,
      property_type: PropertyTypes::BUILDING,
      country: "Chile",
      timezone: "America/Santiago",
      status: PropertyStatuses::INACTIVE
    }
  end
end
