# frozen_string_literal: true

require "test_helper"

class Admin::ResidentialProperties::UnitsMutationsControllerTest < ActionDispatch::IntegrationTest
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @property = create_property(@organization, "Units Mutation Property")
    @other_property = create_property(@organization, "Units Mutation Property Two")
    @floor = @property.property_sections.create!(
      organization: @organization,
      name: "Piso 1",
      section_type: SectionTypes::FLOOR
    )
    @unit = create_unit(@property, "MUT-101")
    @unit.update!(property_section: @floor)

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "units-mut-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @client = create_user_for_organization(
      organization: @organization,
      email: "units-mut-client@example.test",
      role: AvailableRoles::CLIENT
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "update delegates descriptive changes to the service" do
    sign_in_as(@tenant_admin)

    patch admin_residential_property_unit_path(@property, @unit), params: {
      unit: { display_name: "Renamed Unit", status: UnitStatuses::MAINTENANCE }
    }

    @unit.reload
    assert_equal "Renamed Unit", @unit.display_name
    assert_equal UnitStatuses::MAINTENANCE, @unit.status
    assert_equal @floor.id, @unit.property_section_id
  end

  test "restore delegates to the service for soft-deleted units" do
    sign_in_as(@tenant_admin)
    Units::SoftDelete.call(actor: @tenant_admin, unit: @unit)

    post restore_admin_residential_property_unit_path(@property, @unit)

    assert_nil @unit.reload.deleted_at
  end

  test "index search returns only units from the authorized property scope" do
    sign_in_as(@tenant_admin)
    create_unit(@other_property, "MUT-101")

    get admin_residential_property_units_path(@property), params: { search: "mut-101" }

    assert_response :success
    ids = response.parsed_body.fetch("units").map { |row| row["id"] }
    assert_includes ids, @unit.id
    assert_equal 1, ids.size
  end

  test "update is forbidden for users without manage_units" do
    sign_in_as(@client)

    patch admin_residential_property_unit_path(@property, @unit), params: {
      unit: { display_name: "Blocked" }
    }
    assert_nil @unit.reload.display_name
    assert_equal "MUT-101", @unit.identifier
  end

  private

  def sign_in_as(user)
    host! "#{@organization.subdomain}.example.com"
    post user_session_path, params: {
      user: { email: user.email, password: "Password1@" }
    }
  end
end
