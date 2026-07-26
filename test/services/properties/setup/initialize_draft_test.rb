# frozen_string_literal: true

require "test_helper"

class Properties::Setup::InitializeDraftTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "setup-draft@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "creates property in draft status" do
    result = Properties::Setup::InitializeDraft.call(
      actor: @tenant_admin,
      attributes: {
        name: "Wizard Draft",
        property_type: PropertyTypes::BUILDING,
        address_line: "Av. Test 123",
        city: "Santiago",
        estimated_units: 10
      }
    )

    assert result.success?
    assert_equal PropertyStatuses::DRAFT, result.property.status
    assert_equal 2, Properties::Setup::WizardState.current_step(result.property)
  end
end
