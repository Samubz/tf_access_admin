# frozen_string_literal: true

require "test_helper"

class Admin::UnitOwnershipCreateFlowTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Integration Flow Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
    @unit = Unit.create!(
      organization: @organization,
      residential_property: @property,
      identifier: "INT-101",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
    @existing_person = Person.create!(
      organization: @organization,
      display_name: "Integration Existing Owner",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE,
      document_number: "66.666.666-6"
    )
    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "integration-owner-flow@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @ownerships_path = admin_residential_property_unit_ownerships_path(@property, @unit)
    @unit_show_path = admin_residential_property_unit_path(@property, @unit, tab: "owners")
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "create with existing person persists ownership and returns refreshed inertia unit show" do
    sign_in_as(@tenant_admin)

    assert_difference -> { @unit.unit_ownerships.count }, 1 do
      assert_no_difference -> { Person.count } do
        post @ownerships_path, params: {
          unit_ownership: {
            person_id: @existing_person.id,
            ownership_percentage: 35,
            starts_at: Date.current
          }
        }
      end
    end

    assert_redirected_to @unit_show_path

    created = @unit.unit_ownerships.find_by!(person_id: @existing_person.id)
    assert_equal 35, created.ownership_percentage.to_i
    assert_equal UnitOwnership::STATUS_ACTIVE, created.status

    inertia_get @unit_show_path
    assert_response :success

    props = inertia_props
    assert props["ownerships"].any? { |ownership| ownership["id"] == created.id }
    assert_equal @existing_person.id, props["ownerships"].find { |ownership| ownership["id"] == created.id }["person_id"]
    assert_equal 1, props.dig("unit", "ownership_stats", "active_owners_count")
    assert_in_delta 35.0, props.dig("unit", "ownership_stats", "assigned_percentage")
    assert_in_delta 65.0, props.dig("unit", "ownership_stats", "available_percentage")
    assert props["change_history"].any? { |entry| entry["description"].include?(@existing_person.display_name) }
  end

  private

  def sign_in_as(user)
    host! "#{@organization.subdomain}.example.com"
    post user_session_path, params: {
      user: { email: user.email, password: "Password1@" }
    }
  end
end
