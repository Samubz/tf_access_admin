# frozen_string_literal: true

require "test_helper"

# Properties::Create domain service (improve-property-foundation §7).
class Properties::CreateTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "prop-create-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @client = create_user_for_organization(
      organization: @organization,
      email: "prop-create-client@example.test",
      role: AvailableRoles::CLIENT
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  # 7.1 -----------------------------------------------------------------------
  test "7.1 creates a valid property within the actor organization" do
    result = nil
    assert_difference -> { ResidentialProperty.count }, 1 do
      result = Properties::Create.call(
        actor: @tenant_admin,
        attributes: { name: "Service Created", property_type: PropertyTypes::BUILDING }
      )
    end

    assert result.success?
    assert_equal PropertyStatuses::ACTIVE, result.property.status
    assert_equal @organization.id, result.property.organization_id
  end

  # 7.16 / §3.4 ---------------------------------------------------------------
  test "derives organization from context and ignores a client-supplied organization_id" do
    result = Properties::Create.call(
      actor: @tenant_admin,
      attributes: {
        name: "Trusted Org Property",
        property_type: PropertyTypes::BUILDING,
        organization_id: @other_organization.id
      }
    )

    assert result.success?
    assert_equal @organization.id, result.property.organization_id
  end

  # 7.3 -----------------------------------------------------------------------
  test "7.3 returns an invalid result without a name" do
    result = nil
    assert_no_difference -> { ResidentialProperty.count } do
      result = Properties::Create.call(
        actor: @tenant_admin,
        attributes: { name: "  ", property_type: PropertyTypes::BUILDING }
      )
    end

    assert result.invalid?
    assert result.errors.key?(:name)
  end

  # 7.4 -----------------------------------------------------------------------
  test "7.4 returns an invalid result on a duplicate normalized name" do
    create_property(@organization, "Service Dup")

    result = Properties::Create.call(
      actor: @tenant_admin,
      attributes: { name: " service   dup ", property_type: PropertyTypes::BUILDING }
    )

    assert result.invalid?
    assert result.errors.key?(:name)
  end

  # 7.15 ----------------------------------------------------------------------
  test "7.15 denies creation to a user without manage_properties" do
    assert_raises(Pundit::NotAuthorizedError) do
      Properties::Create.call(
        actor: @client,
        attributes: { name: "Forbidden Property", property_type: PropertyTypes::BUILDING }
      )
    end
  end
end
