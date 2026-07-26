# frozen_string_literal: true

require "test_helper"

class Properties::ActivateTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "setup-activate@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @property = create_property(@organization, "Configured Property")
    @property.update!(status: PropertyStatuses::CONFIGURED)
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "activates configured property" do
    result = Properties::Activate.call(actor: @tenant_admin, property: @property)

    assert result.success?
    assert_equal PropertyStatuses::ACTIVE, result.property.status
  end
end
