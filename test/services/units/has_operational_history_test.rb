# frozen_string_literal: true

require "test_helper"

class Units::HasOperationalHistoryTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @property = ResidentialProperty.create!(
      organization: @organization, name: "History Property", property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::ACTIVE, country: "Chile", timezone: "America/Santiago"
    )
    @unit = Unit.create!(
      organization: @organization, residential_property: @property,
      identifier: "101", unit_type: UnitTypes::APARTMENT, status: UnitStatuses::AVAILABLE
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "false for a unit with no operational relations" do
    refute Units::HasOperationalHistory.call(@unit)
  end

  test "true for a unit with an ownership" do
    person = Person.create!(
      organization: @organization, display_name: "Owner", person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    UnitOwnership.create!(
      organization: @organization, unit: @unit, person: person,
      ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
    )

    assert Units::HasOperationalHistory.call(@unit)
  end
end
