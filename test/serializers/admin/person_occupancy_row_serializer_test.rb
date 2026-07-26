# frozen_string_literal: true

require "test_helper"

class Admin::PersonOccupancyRowSerializerTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Occupancy Serializer Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
    @section = PropertySection.create!(
      organization: @organization,
      residential_property: @property,
      name: "Block B",
      section_type: "floor"
    )
    @unit = Unit.create!(
      organization: @organization,
      residential_property: @property,
      property_section: @section,
      identifier: "OCC-SER-101",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
    @person = Person.create!(
      organization: @organization,
      display_name: "Serializer Occupant",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @occupancy = UnitOccupancy.create!(
      organization: @organization,
      unit: @unit,
      person: @person,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: Time.current,
      status: OccupancyStatuses::ACTIVE
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "serializes occupancy row with property section and unit context" do
    occupancy = UnitOccupancy.includes(unit: [ :residential_property, :property_section ]).find(@occupancy.id)
    json = Admin::PersonOccupancyRowSerializer.new(occupancy).as_json

    assert_equal @occupancy.id, json[:id]
    assert_equal OccupancyTypes::TENANT, json[:occupancy_type]
    assert_equal OccupancyStatuses::ACTIVE, json[:status]
    assert json[:occupancy_type_label].present?
    assert json[:status_label].present?
    assert_equal @property.id, json[:residential_property_id]
    assert_equal "Occupancy Serializer Property", json[:residential_property_name]
    assert_equal @section.id, json[:property_section_id]
    assert_equal "Block B", json[:property_section_name]
    assert_equal @unit.id, json[:unit_id]
    assert_equal "OCC-SER-101", json[:unit_identifier]
    assert_equal "current", json[:validity_state]
  end
end
