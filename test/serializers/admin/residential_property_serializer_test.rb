# frozen_string_literal: true

require "test_helper"

# Backend-driven permissions/actions contract exposed to the UI
# (improve-property-foundation §7.19).
class Admin::ResidentialPropertySerializerTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "rp-serializer-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @property_admin = create_staff_user(
      organization: @organization,
      email: "rp-serializer-prop-admin@example.test",
      staff_type: StaffTypes::MANAGER,
      property: create_property(@organization, "Serializer Assigned Property")
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  def serialize(property, user)
    Admin::ResidentialPropertySerializer.new(property, current_user: user).as_json
  end

  test "7.19 active property exposes deactivate and archive to tenant_admin" do
    property = create_property(@organization, "Serializer Active")
    json = serialize(property, @tenant_admin)

    assert json[:permissions][:update]
    assert json[:permissions][:deactivate]
    refute json[:permissions][:activate]
    assert json[:permissions][:archive]
    assert_includes json[:actions], "archive"
    assert_includes json[:actions], "deactivate"
  end

  test "7.19 inactive property exposes activate instead of deactivate" do
    property = create_property(@organization, "Serializer Inactive")
    property.update!(status: PropertyStatuses::INACTIVE)
    json = serialize(property, @tenant_admin)

    assert json[:permissions][:activate]
    refute json[:permissions][:deactivate]
  end

  test "7.19 archived property hides update and archive actions" do
    property = create_property(@organization, "Serializer Archived")
    property.update!(status: PropertyStatuses::ARCHIVED)
    json = serialize(property, @tenant_admin)

    refute json[:permissions][:update]
    refute json[:permissions][:archive]
    assert_empty json[:actions]
  end

  test "7.19 property_admin gets update but never archive" do
    property = create_property(@organization, "Serializer For Prop Admin")
    property_admin = create_staff_user(
      organization: @organization,
      email: "rp-serializer-assigned@example.test",
      staff_type: StaffTypes::MANAGER,
      property: property
    )
    json = serialize(property, property_admin)

    assert json[:permissions][:update]
    refute json[:permissions][:archive]
    refute_includes json[:actions], "archive"
  end
end
