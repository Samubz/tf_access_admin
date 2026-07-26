# frozen_string_literal: true

require "test_helper"

class Admin::PersonOwnershipRowSerializerTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Serializer Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
    @section = PropertySection.create!(
      organization: @organization,
      residential_property: @property,
      name: "Tower A",
      section_type: "floor"
    )
    @unit = Unit.create!(
      organization: @organization,
      residential_property: @property,
      property_section: @section,
      identifier: "SER-101",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
    @person = Person.create!(
      organization: @organization,
      display_name: "Serializer Owner",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @ownership = UnitOwnership.create!(
      organization: @organization,
      unit: @unit,
      person: @person,
      ownership_percentage: 75,
      starts_at: Date.current,
      status: UnitOwnership::STATUS_ACTIVE
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "serializes ownership row with property section and unit context" do
    ownership = UnitOwnership.includes(unit: [ :residential_property, :property_section ]).find(@ownership.id)
    json = Admin::PersonOwnershipRowSerializer.new(ownership).as_json

    assert_equal @ownership.id, json[:id]
    assert_equal 75, json[:ownership_percentage].to_i
    assert_equal UnitOwnership::STATUS_ACTIVE, json[:status]
    assert_equal @property.id, json[:residential_property_id]
    assert_equal "Serializer Property", json[:residential_property_name]
    assert_equal @section.id, json[:property_section_id]
    assert_equal "Tower A", json[:property_section_name]
    assert_equal @unit.id, json[:unit_id]
    assert_equal "SER-101", json[:unit_identifier]
    assert_equal "current", json[:validity_state]
  end
end
