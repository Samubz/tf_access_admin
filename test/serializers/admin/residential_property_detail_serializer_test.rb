# frozen_string_literal: true

require "test_helper"

class Admin::ResidentialPropertyDetailSerializerTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "detail-serializer@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  def serialize(property, actor: @tenant_admin)
    Admin::ResidentialPropertyDetailSerializer.new(property: property, current_user: actor).as_json
  end

  test "permissions.edit is true for a draft property when actor can update setup" do
    property = create_property(@organization, "Detail Draft Property")
    property.update!(status: PropertyStatuses::DRAFT)

    json = serialize(property)

    assert json[:permissions][:edit]
  end

  test "permissions.edit is false for an active property" do
    property = create_property(@organization, "Detail Active Property")

    json = serialize(property)

    refute json[:permissions][:edit]
  end

  test "permissions.edit is false for configured, inactive, and archived properties" do
    property = create_property(@organization, "Detail Non-Editable Property")

    [ PropertyStatuses::CONFIGURED, PropertyStatuses::INACTIVE, PropertyStatuses::ARCHIVED ].each do |status|
      property.update!(status: status)
      refute serialize(property)[:permissions][:edit], "expected edit to be hidden for status #{status}"
    end
  end

  test "permissions.edit is false when the actor is not authorized to update setup" do
    property = create_property(@organization, "Detail Unauthorized Edit Property")
    property.update!(status: PropertyStatuses::DRAFT)
    client = create_user_for_organization(
      organization: @organization,
      email: "detail-client@example.test",
      role: AvailableRoles::CLIENT
    )

    refute serialize(property, actor: client)[:permissions][:edit]
  end

  test "preview counts match Properties::Setup::BuildPreview" do
    property = create_property(@organization, "Detail Preview Property")
    create_unit(property, "101")

    json = serialize(property)
    expected = Properties::Setup::BuildPreview.call(property: property, actor: @tenant_admin)

    assert_equal expected[:counts], json[:preview][:counts]
  end

  test "next_actions includes property_detail when actor can view the property" do
    property = create_property(@organization, "Detail Next Actions Property")

    json = serialize(property)

    assert_includes json[:next_actions], "property_detail"
  end
end
