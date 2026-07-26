# frozen_string_literal: true

require "test_helper"

class Properties::Setup::ResetStructureTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @tenant_admin = create_user_for_organization(
      organization: @organization, email: "reset-structure@example.test", role: AvailableRoles::TENANT_ADMIN
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  def property_with_structure(status:)
    property = ResidentialProperty.create!(
      organization: @organization, name: "Reset #{status}", property_type: PropertyTypes::BUILDING,
      status: status, country: "Chile", timezone: "America/Santiago",
      metadata: { "setup_wizard" => { "structure_mode" => "manual" } }
    )
    section = property.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER
    )
    unit = Unit.create!(
      organization: @organization, residential_property: property, property_section: section,
      identifier: "101", unit_type: UnitTypes::APARTMENT, status: UnitStatuses::AVAILABLE
    )
    [ property, section, unit ]
  end

  test "no reset needed when there is no existing structure" do
    property = ResidentialProperty.create!(
      organization: @organization, name: "Empty Draft", property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::DRAFT, country: "Chile", timezone: "America/Santiago"
    )

    outcome = Properties::Setup::ResetStructure.call(
      actor: @tenant_admin, property: property, new_property_type: PropertyTypes::TOWER
    )

    assert outcome.success?
  end

  test "no reset needed when neither property type nor structure mode changes" do
    property, = property_with_structure(status: PropertyStatuses::DRAFT)

    outcome = Properties::Setup::ResetStructure.call(
      actor: @tenant_admin, property: property,
      new_property_type: property.property_type, new_structure_mode: "manual"
    )

    assert outcome.success?
  end

  test "requires confirmation when property type changes and structure exists" do
    property, section, unit = property_with_structure(status: PropertyStatuses::DRAFT)

    outcome = Properties::Setup::ResetStructure.call(
      actor: @tenant_admin, property: property, new_property_type: PropertyTypes::TOWER
    )

    assert outcome.needs_confirmation?
    assert_nil section.reload.deleted_at
    assert_nil unit.reload.deleted_at
  end

  test "really destroys structure for a draft property once confirmed" do
    property, section, unit = property_with_structure(status: PropertyStatuses::DRAFT)

    outcome = Properties::Setup::ResetStructure.call(
      actor: @tenant_admin, property: property, new_property_type: PropertyTypes::TOWER, confirmed: true
    )

    assert outcome.success?
    assert_raises(ActiveRecord::RecordNotFound) { PropertySection.unscoped.find(section.id) }
    assert_raises(ActiveRecord::RecordNotFound) { Unit.unscoped.find(unit.id) }
  end

  test "soft-deletes structure for a created property with no operational history once confirmed" do
    property, section, unit = property_with_structure(status: PropertyStatuses::CREATED)

    outcome = Properties::Setup::ResetStructure.call(
      actor: @tenant_admin, property: property, new_property_type: PropertyTypes::TOWER, confirmed: true
    )

    assert outcome.success?
    assert_not_nil section.reload.deleted_at
    assert_not_nil unit.reload.deleted_at
  end

  test "archives structure for a configured property with operational history once confirmed" do
    property, section, unit = property_with_structure(status: PropertyStatuses::CONFIGURED)
    person = Person.create!(
      organization: @organization, display_name: "Owner", person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    UnitOwnership.create!(
      organization: @organization, unit: unit, person: person,
      ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
    )

    outcome = Properties::Setup::ResetStructure.call(
      actor: @tenant_admin, property: property, new_property_type: PropertyTypes::TOWER, confirmed: true
    )

    assert outcome.success?
    assert_equal SectionStatuses::ARCHIVED, section.reload.status
    assert_equal UnitStatuses::ARCHIVED, unit.reload.status
    assert_nil section.deleted_at
    assert_nil unit.deleted_at
  end

  test "requires confirmation when structure mode changes and structure exists" do
    property, = property_with_structure(status: PropertyStatuses::CREATED)

    outcome = Properties::Setup::ResetStructure.call(
      actor: @tenant_admin, property: property, new_structure_mode: "none"
    )

    assert outcome.needs_confirmation?
  end
end
