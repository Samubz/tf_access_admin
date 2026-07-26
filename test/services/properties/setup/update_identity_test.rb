# frozen_string_literal: true

require "test_helper"

class Properties::Setup::UpdateIdentityTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "update-identity@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Identity Property",
      property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::CREATED,
      country: "Chile",
      timezone: "America/Santiago"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "regenerates normalized_name and code on name change" do
    old_code = @property.code

    result = Properties::Setup::UpdateIdentity.call(
      actor: @tenant_admin, property: @property, attributes: { name: "Renamed Property" }
    )

    assert result.success?
    assert_equal "renamed property", result.property.normalized_name
    assert_not_equal old_code, result.property.code
  end

  test "does not touch code when identity fields are unchanged" do
    @property.update!(code: "bld-identity-property")

    result = Properties::Setup::UpdateIdentity.call(
      actor: @tenant_admin, property: @property, attributes: { city: "Valparaiso" }
    )

    assert result.success?
    assert_equal "bld-identity-property", result.property.code
    assert_equal "Valparaiso", result.property.city
  end

  test "rejects a name change that collides with another property's code" do
    ResidentialProperty.create!(
      organization: @organization,
      name: "Existing Rival",
      property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::ACTIVE,
      country: "Chile",
      timezone: "America/Santiago",
      code: "bld-rival"
    )

    result = Properties::Setup::UpdateIdentity.call(
      actor: @tenant_admin, property: @property, attributes: { name: "Rival" }
    )

    assert result.invalid?
    assert result.property.errors.key?(:name)
    assert_not_equal "rival", @property.reload.normalized_name
  end
end
