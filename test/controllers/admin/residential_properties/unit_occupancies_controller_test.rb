# frozen_string_literal: true

require "test_helper"

class Admin::ResidentialProperties::UnitOccupanciesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Occupancies Controller Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
    @unit = Unit.create!(
      organization: @organization,
      residential_property: @property,
      identifier: "OCC-CTRL-101",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
    @person = Person.create!(
      organization: @organization,
      display_name: "Occupancies Controller Person",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @occupancy = UnitOccupancy.create!(
      organization: @organization,
      unit: @unit,
      person: @person,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: Time.current,
      status: "active"
    )

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "tenant-admin-occupancies@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @non_admin = create_user_for_organization(
      organization: @organization,
      email: "non-admin-occupancies@example.test",
      role: AvailableRoles::CLIENT
    )

    @occupancies_path = admin_residential_property_unit_occupancies_path(@property, @unit)
    @occupancy_path = admin_residential_property_unit_occupancy_path(@property, @unit, @occupancy)
    @unit_show_path = admin_residential_property_unit_path(@property, @unit, tab: "occupants")
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "create is forbidden for non-admin users" do
    sign_in_as(@non_admin)

    assert_no_difference -> { @unit.unit_occupancies.count } do
      post @occupancies_path, params: {
        unit_occupancy: {
          person_id: @person.id,
          occupancy_type: OccupancyTypes::TENANT,
          starts_at: Time.current
        }
      }
    end

    assert_redirected_to admin_residential_properties_path
  end

  test "update is forbidden for non-admin users" do
    sign_in_as(@non_admin)

    assert_no_changes -> { @occupancy.reload.occupancy_type } do
      patch @occupancy_path, params: {
        unit_occupancy: { occupancy_type: OccupancyTypes::FAMILY_MEMBER }
      }
    end

    assert_redirected_to admin_residential_properties_path
  end

  test "destroy is forbidden for non-admin users" do
    sign_in_as(@non_admin)

    assert_no_difference -> { @unit.unit_occupancies.count } do
      delete @occupancy_path
    end

    assert_redirected_to admin_residential_properties_path
  end

  test "create is forbidden for tenant admin from another organization" do
    other_organization = organizations(:two)
    other_property = ActsAsTenant.without_tenant do
      ResidentialProperty.create!(
        organization: other_organization,
        name: "Other Org Occupancies Property",
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
        identifier: "OTH-OCC-CTRL-101",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
    end
    other_person = ActsAsTenant.without_tenant do
      Person.create!(
        organization: other_organization,
        display_name: "Other Org Occupancies Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
    end

    sign_in_as(@tenant_admin)

    assert_no_difference -> { UnitOccupancy.unscoped.count } do
      post admin_residential_property_unit_occupancies_path(other_property, other_unit), params: {
        unit_occupancy: {
          person_id: other_person.id,
          occupancy_type: OccupancyTypes::TENANT,
          starts_at: Time.current
        }
      }
    end

    assert_redirected_to admin_residential_properties_path
  end

  test "tenant admin create delegates to service layer" do
    sign_in_as(@tenant_admin)
    other_person = Person.create!(
      organization: @organization,
      display_name: "Controller Create Occupant",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )

    assert_difference -> { @unit.unit_occupancies.count }, 1 do
      post @occupancies_path, params: {
        unit_occupancy: {
          person_id: other_person.id,
          occupancy_type: OccupancyTypes::TENANT,
          can_authorize_visits: true,
          starts_at: Date.current
        }
      }
    end

    assert_redirected_to @unit_show_path
  end

  test "tenant admin create with new person delegates to CreateWithPerson service" do
    sign_in_as(@tenant_admin)

    assert_difference -> { Person.count }, 1 do
      assert_difference -> { @unit.unit_occupancies.count }, 1 do
        post @occupancies_path, params: {
          unit_occupancy: {
            occupancy_type: OccupancyTypes::TENANT,
            starts_at: Date.current
          },
          person: {
            first_name: "Drawer",
            last_name: "Occupant",
            document_number: "99.999.999-9",
            email: "drawer-occupant@example.test",
            person_type: PersonTypes::NATURAL
          }
        }
      end
    end

    assert_redirected_to @unit_show_path
  end

  test "tenant admin update delegates to service layer" do
    sign_in_as(@tenant_admin)

    patch @occupancy_path, params: {
      unit_occupancy: { can_authorize_visits: true, occupancy_type: OccupancyTypes::FAMILY_MEMBER }
    }

    assert_redirected_to @unit_show_path
    assert @occupancy.reload.can_authorize_visits
    assert_equal OccupancyTypes::FAMILY_MEMBER, @occupancy.occupancy_type
  end

  test "update with invalid dates redirects with inertia errors" do
    sign_in_as(@tenant_admin)

    assert_no_changes -> { @occupancy.reload.starts_at } do
      patch @occupancy_path, params: {
        unit_occupancy: {
          occupancy_type: OccupancyTypes::TENANT,
          starts_at: Date.current,
          ends_at: Date.current - 1.day
        }
      }
    end

    assert_redirected_to @unit_show_path
    assert_equal(
      inertia_field_error(UnitOccupancy, :ends_at, validation_key("ends_at_before_starts_at")),
      session[:inertia_errors]
    )
  end

  test "update occupancy type and status via patch" do
    sign_in_as(@tenant_admin)

    patch @occupancy_path, params: {
      unit_occupancy: {
        occupancy_type: OccupancyTypes::OWNER_RESIDENT,
        can_authorize_visits: false,
        status: OccupancyStatuses::INACTIVE,
        starts_at: Date.current
      }
    }

    assert_redirected_to @unit_show_path
    @occupancy.reload
    assert_equal OccupancyTypes::OWNER_RESIDENT, @occupancy.occupancy_type
    assert_equal OccupancyStatuses::INACTIVE, @occupancy.status
    assert_not @occupancy.can_authorize_visits
  end

  test "tenant admin destroy delegates to Destroy service for soft delete" do
    sign_in_as(@tenant_admin)
    occupancy_id = @occupancy.id

    delete @occupancy_path

    assert_redirected_to @unit_show_path
    assert_nil UnitOccupancy.find_by(id: occupancy_id)
    assert UnitOccupancy.with_deleted.exists?(id: occupancy_id)
  end

  test "create with duplicate active occupancy redirects with inertia errors" do
    sign_in_as(@tenant_admin)

    assert_no_difference -> { @unit.unit_occupancies.count } do
      post @occupancies_path, params: {
        unit_occupancy: {
          person_id: @person.id,
          occupancy_type: OccupancyTypes::TENANT,
          starts_at: Date.current
        }
      }
    end

    assert_redirected_to @unit_show_path
    assert_equal(
      inertia_field_error(UnitOccupancy, :person_id, validation_key("duplicate_active_person")),
      session[:inertia_errors]
    )
  end

  test "create with invalid dates redirects with inertia errors" do
    sign_in_as(@tenant_admin)

    other_person = Person.create!(
      organization: @organization,
      display_name: "Invalid Dates Occupant",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )

    assert_no_difference -> { @unit.unit_occupancies.count } do
      post @occupancies_path, params: {
        unit_occupancy: {
          person_id: other_person.id,
          occupancy_type: OccupancyTypes::TENANT,
          starts_at: Date.current,
          ends_at: Date.current - 1.day
        }
      }
    end

    assert_redirected_to @unit_show_path
    assert_equal(
      inertia_field_error(UnitOccupancy, :ends_at, validation_key("ends_at_before_starts_at")),
      session[:inertia_errors]
    )
  end

  test "active_elsewhere includes property section when present" do
    sign_in_as(@tenant_admin)

    other_property = ResidentialProperty.create!(
      organization: @organization,
      name: "Other Active Elsewhere Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
    other_section = PropertySection.create!(
      organization: @organization,
      residential_property: other_property,
      name: "Tower A",
      section_type: SectionTypes::TOWER
    )
    other_unit = Unit.create!(
      organization: @organization,
      residential_property: other_property,
      property_section: other_section,
      identifier: "OTH-WARN-101",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
    UnitOccupancy.create!(
      organization: @organization,
      unit: other_unit,
      person: @person,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: Time.current,
      status: OccupancyStatuses::ACTIVE
    )

    get active_elsewhere_admin_residential_property_unit_occupancies_path(@property, @unit, person_id: @person.id)

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal 1, payload["active_elsewhere_occupancies"].size
    assert_equal "OTH-WARN-101", payload.dig("active_elsewhere_occupancies", 0, "unit", "identifier")
    assert_equal other_property.name, payload.dig("active_elsewhere_occupancies", 0, "property", "name")
    assert_equal "Tower A", payload.dig("active_elsewhere_occupancies", 0, "property_section", "name")
  end

  test "update is forbidden for tenant admin from another organization" do
    other_occupancy = ActsAsTenant.without_tenant do
      other_organization = organizations(:two)
      other_property = ResidentialProperty.create!(
        organization: other_organization,
        name: "Other Org Update Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      other_unit = Unit.create!(
        organization: other_organization,
        residential_property: other_property,
        identifier: "OTH-OCC-UPD-101",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
      other_person = Person.create!(
        organization: other_organization,
        display_name: "Other Org Update Occupant",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      UnitOccupancy.create!(
        organization: other_organization,
        unit: other_unit,
        person: other_person,
        occupancy_type: OccupancyTypes::TENANT,
        starts_at: Time.current,
        status: "active"
      )
    end

    sign_in_as(@tenant_admin)

    assert_no_changes -> { other_occupancy.reload.can_authorize_visits } do
      patch admin_residential_property_unit_occupancy_path(@property, @unit, other_occupancy), params: {
        unit_occupancy: { can_authorize_visits: true }
      }
    end

    assert_redirected_to @unit_show_path
  end

  test "destroy is forbidden for tenant admin from another organization" do
    other_occupancy = ActsAsTenant.without_tenant do
      other_organization = organizations(:two)
      other_property = ResidentialProperty.create!(
        organization: other_organization,
        name: "Other Org Destroy Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      other_unit = Unit.create!(
        organization: other_organization,
        residential_property: other_property,
        identifier: "OTH-OCC-DEL-101",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
      other_person = Person.create!(
        organization: other_organization,
        display_name: "Other Org Destroy Occupant",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      UnitOccupancy.create!(
        organization: other_organization,
        unit: other_unit,
        person: other_person,
        occupancy_type: OccupancyTypes::TENANT,
        starts_at: Time.current,
        status: "active"
      )
    end

    sign_in_as(@tenant_admin)

    assert_no_changes -> { other_occupancy.reload.deleted_at } do
      delete admin_residential_property_unit_occupancy_path(@property, @unit, other_occupancy)
    end

    assert_redirected_to @unit_show_path
  end

  private

  def validation_key(name)
    "admin.unit_occupancies.validations.#{name}"
  end

  def sign_in_as(user)
    host! "#{@organization.subdomain}.example.com"
    post user_session_path, params: {
      user: { email: user.email, password: "Password1@" }
    }
  end
end
