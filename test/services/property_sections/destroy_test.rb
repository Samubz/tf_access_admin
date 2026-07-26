# frozen_string_literal: true

require "test_helper"

# Draft-phase soft delete of a section (wizard-manual-structure-builder).
class PropertySections::DestroyTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @actor = create_user_for_organization(
      organization: @organization,
      email: "destroy-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @property = draft_property(@organization, "Destroy Draft Property")
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "soft-deletes an empty leaf section on a draft property" do
    section = root_section(@property, "Torre A")

    result = PropertySections::Destroy.call(actor: @actor, section: section)

    assert result.success?
    assert_predicate section, :destroyed?
    assert_not_nil section.reload.deleted_at
    assert_empty @property.property_sections.where(id: section.id)
  end

  test "blocks deletion when the section has children" do
    parent = root_section(@property, "Torre A")
    @property.property_sections.create!(
      organization: @organization, name: "Piso 1",
      section_type: SectionTypes::FLOOR, parent: parent
    )

    result = PropertySections::Destroy.call(actor: @actor, section: parent)

    assert result.invalid?
    assert_predicate parent.reload, :persisted?
    assert_nil parent.deleted_at
  end

  test "blocks deletion when the section has units" do
    section = root_section(@property, "Torre A")
    Unit.create!(
      organization: @organization, residential_property: @property,
      property_section: section, identifier: "U-1",
      unit_type: UnitTypes::APARTMENT, status: UnitStatuses::AVAILABLE
    )

    result = PropertySections::Destroy.call(actor: @actor, section: section)

    assert result.invalid?
    assert_nil section.reload.deleted_at
  end

  test "allows deletion when the property is configured" do
    configured = ResidentialProperty.create!(
      organization: @organization, name: "Configured Property",
      property_type: PropertyTypes::BUILDING, status: PropertyStatuses::CONFIGURED,
      country: "Chile", timezone: "America/Santiago"
    )
    section = root_section(configured, "Torre A")

    result = PropertySections::Destroy.call(actor: @actor, section: section)

    assert result.success?
    assert_not_nil section.reload.deleted_at
  end

  test "rejects deletion when the property is inactive or archived" do
    inactive = ResidentialProperty.create!(
      organization: @organization, name: "Inactive Property",
      property_type: PropertyTypes::BUILDING, status: PropertyStatuses::INACTIVE,
      country: "Chile", timezone: "America/Santiago"
    )
    section = root_section(inactive, "Torre A")

    result = PropertySections::Destroy.call(actor: @actor, section: section)

    assert result.invalid?
    assert result.errors.of_kind?(:base, :property_not_operative)
    assert_nil section.reload.deleted_at
  end

  test "is idempotent when the section is already deleted" do
    section = root_section(@property, "Torre A")
    section.destroy

    result = PropertySections::Destroy.call(actor: @actor, section: section)

    assert result.noop?
  end

  private

  def draft_property(organization, name)
    ResidentialProperty.create!(
      organization: organization, name: name,
      property_type: PropertyTypes::BUILDING, status: PropertyStatuses::DRAFT,
      country: "Chile", timezone: "America/Santiago"
    )
  end

  def root_section(property, name)
    property.property_sections.create!(
      organization: property.organization, name: name, section_type: SectionTypes::TOWER
    )
  end
end
