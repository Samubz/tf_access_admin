# frozen_string_literal: true

require "test_helper"

class Person::ProfileSummaryTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Summary Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
    @unit = Unit.create!(
      organization: @organization,
      residential_property: @property,
      identifier: "SUM-101",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
    @person = Person.create!(
      organization: @organization,
      display_name: "Summary Person",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "returns active relationship counts and placeholder future metrics" do
    UnitOwnership.create!(
      organization: @organization,
      unit: @unit,
      person: @person,
      ownership_percentage: 50,
      starts_at: Date.current,
      status: UnitOwnership::STATUS_ACTIVE
    )
    UnitOccupancy.create!(
      organization: @organization,
      unit: @unit,
      person: @person,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: Time.current,
      status: OccupancyStatuses::ACTIVE
    )

    summary = Person::ProfileSummary.for(@person)

    assert_equal 1, summary[:active_ownerships_count]
    assert_equal 1, summary[:active_occupancies_count]
    assert_equal 0, summary[:visits_count]
    assert_equal 0, summary[:staff_assignments_count]
  end
end
