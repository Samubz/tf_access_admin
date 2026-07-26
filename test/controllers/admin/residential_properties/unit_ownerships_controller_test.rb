# frozen_string_literal: true

require "test_helper"

class Admin::ResidentialProperties::UnitOwnershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Controller Test Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
    @unit = Unit.create!(
      organization: @organization,
      residential_property: @property,
      identifier: "CTRL-101",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
    @person = Person.create!(
      organization: @organization,
      display_name: "Controller Owner",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @other_person = Person.create!(
      organization: @organization,
      display_name: "Other Controller Owner",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @ownership = UnitOwnership.create!(
      organization: @organization,
      unit: @unit,
      person: @person,
      ownership_percentage: 50,
      starts_at: Date.current,
      status: UnitOwnership::STATUS_ACTIVE
    )

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "tenant-admin-ownerships@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @non_admin = create_user_for_organization(
      organization: @organization,
      email: "non-admin-ownerships@example.test",
      role: AvailableRoles::CLIENT
    )

    @ownerships_path = admin_residential_property_unit_ownerships_path(@property, @unit)
    @ownership_path = admin_residential_property_unit_ownership_path(@property, @unit, @ownership)
    @unit_show_path = admin_residential_property_unit_path(@property, @unit, tab: "owners")
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "create with existing person redirects to unit show and updates stats" do
    sign_in_as(@tenant_admin)

    assert_difference -> { @unit.unit_ownerships.count }, 1 do
      post @ownerships_path, params: {
        unit_ownership: {
          person_id: @other_person.id,
          ownership_percentage: 30,
          starts_at: Date.current
        }
      }
    end

    assert_redirected_to @unit_show_path

    inertia_get @unit_show_path
    assert_response :success

    props = inertia_props
    assert_equal 2, props.dig("unit", "ownership_stats", "active_owners_count")
    assert_in_delta 80.0, props.dig("unit", "ownership_stats", "assigned_percentage")
    assert props["change_history"].any? { |entry| entry["description"].present? }
    assert props["ownerships"].any? { |ownership| ownership["person_id"] == @other_person.id }
  end

  test "create with new person redirects to unit show and persists person fields" do
    sign_in_as(@tenant_admin)

    assert_difference -> { Person.count }, 1 do
      assert_difference -> { @unit.unit_ownerships.count }, 1 do
        post @ownerships_path, params: {
          unit_ownership: {
            ownership_percentage: 25,
            starts_at: Date.current
          },
          person: {
            first_name: "Drawer",
            last_name: "Created Owner",
            document_number: "55.555.555-5",
            email: "drawer-owner@example.test",
            person_type: PersonTypes::NATURAL
          }
        }
      end
    end

    assert_redirected_to @unit_show_path

    created_person = Person.order(:created_at).last
    assert_equal "Drawer", created_person.first_name
    assert_equal "Created Owner", created_person.last_name
    assert_equal "Drawer Created Owner", created_person.display_name
    assert_equal "55.555.555-5", created_person.document_number
    assert_equal "drawer-owner@example.test", created_person.contact_email
    assert created_person.organization_membership&.active?
  end

  test "create validation error redirects to unit show with inertia errors" do
    sign_in_as(@tenant_admin)

    assert_no_difference -> { @unit.unit_ownerships.count } do
      post @ownerships_path, params: {
        unit_ownership: {
          person_id: @other_person.id,
          ownership_percentage: 60,
          starts_at: Date.current
        }
      }
    end

    assert_redirected_to @unit_show_path
    assert_equal(
      inertia_field_error(UnitOwnership, :ownership_percentage, validation_key("percentage_sum_exceeded")),
      session[:inertia_errors]
    )
  end

  test "update redirects to unit show and refreshes stats" do
    sign_in_as(@tenant_admin)

    patch @ownership_path, params: {
      unit_ownership: { ownership_percentage: 40 }
    }

    assert_redirected_to @unit_show_path
    assert_equal 40, @ownership.reload.ownership_percentage.to_i

    inertia_get @unit_show_path
    assert_in_delta 40.0, inertia_props.dig("unit", "ownership_stats", "assigned_percentage")
  end

  test "update validation error redirects to unit show with inertia errors" do
    sign_in_as(@tenant_admin)

    patch @ownership_path, params: {
      unit_ownership: { ends_at: Date.current - 1.day }
    }

    assert_redirected_to @unit_show_path
    assert_equal(
      inertia_field_error(UnitOwnership, :ends_at, validation_key("ends_at_before_starts_at")),
      session[:inertia_errors]
    )
    assert_nil @ownership.reload.ends_at
  end

  test "destroy redirects to unit show and removes active ownership from stats" do
    sign_in_as(@tenant_admin)

    delete @ownership_path

    assert_redirected_to @unit_show_path
    assert_nil UnitOwnership.find_by(id: @ownership.id)
    assert UnitOwnership.with_deleted.exists?(id: @ownership.id)

    inertia_get @unit_show_path
    assert_equal 0, inertia_props.dig("unit", "ownership_stats", "active_owners_count")
    assert_not inertia_props["ownerships"].any? { |ownership| ownership["id"] == @ownership.id }
  end

  test "create is forbidden for non-admin users" do
    sign_in_as(@non_admin)

    assert_no_difference -> { @unit.unit_ownerships.count } do
      post @ownerships_path, params: {
        unit_ownership: {
          person_id: @person.id,
          ownership_percentage: 25,
          starts_at: Date.current
        }
      }
    end

    assert_redirected_to admin_residential_properties_path
  end

  test "update is forbidden for non-admin users" do
    sign_in_as(@non_admin)

    assert_no_changes -> { @ownership.reload.ownership_percentage } do
      patch @ownership_path, params: {
        unit_ownership: { ownership_percentage: 40 }
      }
    end

    assert_redirected_to admin_residential_properties_path
  end

  test "destroy is forbidden for non-admin users" do
    sign_in_as(@non_admin)

    assert_no_difference -> { @unit.unit_ownerships.with_deleted.count } do
      delete @ownership_path
    end

    assert_redirected_to admin_residential_properties_path
  end

  test "create is forbidden for tenant admin from another organization" do
    other_organization = organizations(:two)
    other_property = ActsAsTenant.without_tenant do
      ResidentialProperty.create!(
        organization: other_organization,
        name: "Other Org Controller Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
    end
    other_unit = ActsAsTenant.without_tenant do
      Unit.create!(
        organization: other_organization,
        residential_property: other_property,
        identifier: "OTH-CTRL-101",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
    end
    other_person = ActsAsTenant.without_tenant do
      Person.create!(
        organization: other_organization,
        display_name: "Other Org Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
    end

    sign_in_as(@tenant_admin)

    assert_no_difference -> { UnitOwnership.unscoped.count } do
      post admin_residential_property_unit_ownerships_path(other_property, other_unit), params: {
        unit_ownership: {
          person_id: other_person.id,
          ownership_percentage: 25,
          starts_at: Date.current
        }
      }
    end

    assert_redirected_to admin_residential_properties_path
  end

  test "destroy validation error redirects to unit show with inertia errors" do
    sign_in_as(@tenant_admin)

    other_ownership = UnitOwnership.create!(
      organization: @organization,
      unit: @unit,
      person: @other_person,
      ownership_percentage: 40,
      starts_at: Date.current,
      status: UnitOwnership::STATUS_ACTIVE
    )

    patch admin_residential_property_unit_ownership_path(@property, @unit, other_ownership), params: {
      unit_ownership: { ownership_percentage: 70 }
    }

    assert_redirected_to @unit_show_path
    assert_equal(
      inertia_field_error(UnitOwnership, :ownership_percentage, validation_key("percentage_sum_exceeded")),
      session[:inertia_errors]
    )
    assert_equal 40, other_ownership.reload.ownership_percentage.to_i
  end

  private

  def sign_in_as(user)
    host! "#{@organization.subdomain}.example.com"
    post user_session_path, params: {
      user: { email: user.email, password: "Password1@" }
    }
  end

  def validation_key(name)
    "admin.unit_ownerships.validations.#{name}"
  end
end
