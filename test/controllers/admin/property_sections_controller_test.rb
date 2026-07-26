# frozen_string_literal: true

require "test_helper"

class Admin::PropertySectionsControllerTest < ActionDispatch::IntegrationTest
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "flat-sections-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @property = ResidentialProperty.create!(
      organization: @organization, name: "Flat Sections Property", property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::ACTIVE, country: "Chile", timezone: "America/Santiago"
    )
    @section = @property.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "edit redirects into the property's setup wizard" do
    sign_in_as(@tenant_admin)

    get edit_admin_property_section_path(@section)

    assert_redirected_to admin_property_setup_wizard_path(@property)
  end

  private

  def sign_in_as(user)
    host! "#{@organization.subdomain}.example.com"
    post user_session_path, params: { user: { email: user.email, password: "Password1@" } }
  end
end
