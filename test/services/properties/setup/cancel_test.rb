# frozen_string_literal: true

require "test_helper"

class Properties::Setup::CancelTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "setup-cancel@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Cancel Property",
      property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::DRAFT,
      country: "Chile",
      timezone: "America/Santiago"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "delete_draft destroys draft property" do
    assert_difference -> { ResidentialProperty.count }, -1 do
      Properties::Setup::Cancel.call(actor: @tenant_admin, property: @property, delete_draft: true)
    end
  end

  test "configured cancel is noop" do
    @property.update!(status: PropertyStatuses::CONFIGURED)

    result = Properties::Setup::Cancel.call(actor: @tenant_admin, property: @property, delete_draft: true)

    assert result.noop?
    assert ResidentialProperty.exists?(@property.id)
  end
end
