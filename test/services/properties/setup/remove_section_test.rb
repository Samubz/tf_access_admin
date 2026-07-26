# frozen_string_literal: true

require "test_helper"

class Properties::Setup::RemoveSectionTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @tenant_admin = create_user_for_organization(
      organization: @organization, email: "remove-section@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    @property = ResidentialProperty.create!(
      organization: @organization, name: "Remove Section Property", property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::CREATED, country: "Chile", timezone: "America/Santiago"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "soft-deletes a section and its units when none has operational history" do
    section = @property.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )
    unit = Unit.create!(
      organization: @organization, residential_property: @property, property_section: section,
      identifier: "101", unit_type: UnitTypes::APARTMENT, status: UnitStatuses::AVAILABLE
    )

    outcome = Properties::Setup::RemoveSection.call(actor: @tenant_admin, section: section)

    assert outcome.success?
    assert_not_nil section.reload.deleted_at
    assert_not_nil unit.reload.deleted_at
  end

  test "requires confirmation and archives a section and its units when a unit has operational history" do
    section = @property.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )
    unit = Unit.create!(
      organization: @organization, residential_property: @property, property_section: section,
      identifier: "101", unit_type: UnitTypes::APARTMENT, status: UnitStatuses::AVAILABLE
    )
    person = Person.create!(
      organization: @organization, display_name: "Owner", person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    UnitOwnership.create!(
      organization: @organization, unit: unit, person: person,
      ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
    )

    unconfirmed = Properties::Setup::RemoveSection.call(actor: @tenant_admin, section: section)
    assert unconfirmed.needs_confirmation?
    assert_nil section.reload.deleted_at

    confirmed = Properties::Setup::RemoveSection.call(actor: @tenant_admin, section: section, confirmed: true)
    assert confirmed.success?
    assert_equal SectionStatuses::ARCHIVED, section.reload.status
    assert_nil section.deleted_at
    assert_equal UnitStatuses::ARCHIVED, unit.reload.status
  end

  test "blocks removal of a root section that still has a child section" do
    root = @property.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )
    child = @property.property_sections.create!(
      organization: @organization, name: "Piso 1", section_type: SectionTypes::FLOOR, parent: root
    )

    outcome = Properties::Setup::RemoveSection.call(actor: @tenant_admin, section: root)

    assert outcome.invalid?
    assert_nil root.reload.deleted_at
    assert_nil child.reload.deleted_at
  end

  test "removing the child section first allows the root section to be removed afterward" do
    root = @property.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )
    child = @property.property_sections.create!(
      organization: @organization, name: "Piso 1", section_type: SectionTypes::FLOOR, parent: root
    )

    child_outcome = Properties::Setup::RemoveSection.call(actor: @tenant_admin, section: child)
    assert child_outcome.success?

    root_outcome = Properties::Setup::RemoveSection.call(actor: @tenant_admin, section: root)
    assert root_outcome.success?
    assert_not_nil root.reload.deleted_at
  end
end
