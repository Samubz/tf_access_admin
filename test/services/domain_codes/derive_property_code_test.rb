# frozen_string_literal: true

require "test_helper"

class DomainCodes::DerivePropertyCodeTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.reset
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "derives {type_abbrev}-{name_slug}" do
    property = ResidentialProperty.new(
      organization: @organization, property_type: PropertyTypes::BUILDING, name: "Torre Sur"
    )

    assert_equal "bld-torre-sur", DomainCodes::DerivePropertyCode.call(property: property)
  end

  test "appends a numeric suffix on organization-scoped collision" do
    ResidentialProperty.create!(
      organization: @organization, name: "Torre Sur", property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::ACTIVE, country: "Chile", timezone: "America/Santiago",
      code: "bld-torre-sur"
    )

    property = ResidentialProperty.new(
      organization: @organization, property_type: PropertyTypes::BUILDING, name: "Torre Sur"
    )

    assert_equal "bld-torre-sur-2", DomainCodes::DerivePropertyCode.call(property: property)
  end

  test "Properties::InitializeDraft derives code and ignores client-submitted code" do
    actor = create_user_for_organization(
      organization: @organization, email: "derive-prop-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    result = Properties::Setup::InitializeDraft.call(
      actor: actor,
      attributes: { name: "Edificio Central", property_type: PropertyTypes::BUILDING, code: "CUSTOM" }
    )

    assert result.property.persisted?
    assert_equal "bld-edificio-central", result.property.code
  end
end
