# frozen_string_literal: true

require "test_helper"

class Properties::Setup::RemoveUnitTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @tenant_admin = create_user_for_organization(
      organization: @organization, email: "remove-unit@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    @property = ResidentialProperty.create!(
      organization: @organization, name: "Remove Unit Property", property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::CREATED, country: "Chile", timezone: "America/Santiago"
    )
    @unit = Unit.create!(
      organization: @organization, residential_property: @property,
      identifier: "101", unit_type: UnitTypes::APARTMENT, status: UnitStatuses::AVAILABLE
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "soft-deletes a unit with no operational history" do
    outcome = Properties::Setup::RemoveUnit.call(actor: @tenant_admin, unit: @unit)

    assert outcome.success?
    assert_not_nil @unit.reload.deleted_at
  end

  test "requires confirmation and archives a unit with operational history" do
    person = Person.create!(
      organization: @organization, display_name: "Owner", person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    UnitOwnership.create!(
      organization: @organization, unit: @unit, person: person,
      ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
    )

    unconfirmed = Properties::Setup::RemoveUnit.call(actor: @tenant_admin, unit: @unit)
    assert unconfirmed.needs_confirmation?
    assert_nil @unit.reload.deleted_at
    assert_not_equal UnitStatuses::ARCHIVED, @unit.status

    confirmed = Properties::Setup::RemoveUnit.call(actor: @tenant_admin, unit: @unit, confirmed: true)
    assert confirmed.success?
    assert_equal UnitStatuses::ARCHIVED, @unit.reload.status
    assert_nil @unit.deleted_at
  end
end
