# frozen_string_literal: true

require "test_helper"

class ResidentialPropertyPolicySetupTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "setup-policy-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @client = create_user_for_organization(
      organization: @organization,
      email: "setup-policy-client@example.test",
      role: AvailableRoles::CLIENT
    )
    @draft = ResidentialProperty.create!(
      organization: @organization,
      name: "Policy Draft",
      property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::DRAFT,
      country: "Chile",
      timezone: "America/Santiago"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "tenant admin can create and update draft in organization" do
    policy = ResidentialPropertyPolicy.new(@tenant_admin, ResidentialProperty.new)

    assert policy.create?
    assert ResidentialPropertyPolicy.new(@tenant_admin, @draft).update?
  end

  test "client cannot create properties" do
    policy = ResidentialPropertyPolicy.new(@client, ResidentialProperty.new)

    refute policy.create?
  end

  test "tenant admin cannot update draft from another organization" do
    other_draft = ActsAsTenant.with_tenant(@other_organization) do
      ResidentialProperty.create!(
        organization: @other_organization,
        name: "Cross Org Draft",
        property_type: PropertyTypes::BUILDING,
        status: PropertyStatuses::DRAFT,
        country: "Chile",
        timezone: "America/Santiago"
      )
    end

    policy = ResidentialPropertyPolicy.new(@tenant_admin, other_draft)

    refute policy.update?
  end
end
