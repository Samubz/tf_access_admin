# frozen_string_literal: true

require "test_helper"

class Properties::Setup::CompleteTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "setup-complete@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Complete Property",
      property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::DRAFT,
      country: "Chile",
      timezone: "America/Santiago",
      metadata: { "setup_wizard" => { "structure_mode" => "none", "units_mode" => "individual" } }
    )
    Units::Create.call(
      actor: @tenant_admin, property: @property,
      attributes: { identifier: "101", unit_type: UnitTypes::APARTMENT }
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "transitions valid draft to created" do
    result = Properties::Setup::Complete.call(actor: @tenant_admin, property: @property.reload)

    assert result.success?
    assert_equal PropertyStatuses::CREATED, result.property.status
  end

  test "rejects an incomplete setup" do
    incomplete = ResidentialProperty.create!(
      organization: @organization,
      name: "Incomplete Property",
      property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::DRAFT,
      country: "Chile",
      timezone: "America/Santiago",
      metadata: { "setup_wizard" => { "structure_mode" => "none", "units_mode" => "individual" } }
    )

    result = Properties::Setup::Complete.call(actor: @tenant_admin, property: incomplete)

    assert result.invalid?
    assert_equal PropertyStatuses::DRAFT, incomplete.reload.status
  end

  test "rejects non-draft properties" do
    @property.update!(status: PropertyStatuses::CONFIGURED)

    result = Properties::Setup::Complete.call(actor: @tenant_admin, property: @property)

    assert result.invalid?
    assert_equal PropertyStatuses::CONFIGURED, @property.reload.status
  end
end
