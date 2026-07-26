# frozen_string_literal: true

require "test_helper"

class Properties::Setup::ConfigureTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "setup-configure@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Configure Property",
      property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::DRAFT,
      country: "Chile",
      timezone: "America/Santiago"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "transitions draft to configured" do
    result = Properties::Setup::Configure.call(actor: @tenant_admin, property: @property)

    assert result.success?
    assert_equal PropertyStatuses::CONFIGURED, result.property.status
  end

  test "transitions created to configured" do
    @property.update!(status: PropertyStatuses::CREATED)

    result = Properties::Setup::Configure.call(actor: @tenant_admin, property: @property)

    assert result.success?
    assert_equal PropertyStatuses::CONFIGURED, result.property.status
  end

  test "rejects active to configured" do
    @property.update!(status: PropertyStatuses::ACTIVE)

    result = Properties::Setup::Configure.call(actor: @tenant_admin, property: @property)

    assert result.invalid?
    assert_equal PropertyStatuses::ACTIVE, @property.reload.status
  end
end
