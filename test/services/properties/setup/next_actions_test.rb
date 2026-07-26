# frozen_string_literal: true

require "test_helper"

class Properties::Setup::NextActionsTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "next-actions@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "includes property_detail when actor can view the property" do
    property = create_property(@organization, "Next Actions Property")

    actions = Properties::Setup::NextActions.call(property: property, actor: @tenant_admin)

    assert_includes actions, "property_detail"
  end

  test "includes reopen_setup only for wizard-editable statuses" do
    property = create_property(@organization, "Next Actions Reopen Property")
    property.update!(status: PropertyStatuses::DRAFT)

    refute_includes Properties::Setup::NextActions.call(property: property, actor: @tenant_admin), "reopen_setup"

    property.update!(status: PropertyStatuses::CREATED)

    assert_includes Properties::Setup::NextActions.call(property: property, actor: @tenant_admin), "reopen_setup"
  end

  test "returns empty array for a non-persisted property" do
    property = ResidentialProperty.new

    assert_equal [], Properties::Setup::NextActions.call(property: property, actor: @tenant_admin)
  end
end
