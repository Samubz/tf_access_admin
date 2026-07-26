# frozen_string_literal: true

require "test_helper"

class DomainCodes::DeriveUnitCodeTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @actor = create_user_for_organization(
      organization: @organization, email: "derive-unit-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @property = ResidentialProperty.create!(
      organization: @organization, name: "Torre Sur", property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::ACTIVE, country: "Chile", timezone: "America/Santiago",
      code: "bld-torre-sur"
    )
    @section = @property.property_sections.create!(
      organization: @organization, name: "Torre A", section_type: SectionTypes::TOWER,
      code: "bld-torre-sur-tor-torre-a"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "sectioned unit derives {section_code}-{normalized_identifier} from accented identifier" do
    unit = create_unit(identifier: "Área 4", section_id: @section.id)

    assert_equal "area-4", unit.normalized_identifier
    assert_equal "bld-torre-sur-tor-torre-a-area-4", unit.code
  end

  test "root-level unit derives {property_code}-{normalized_identifier}" do
    unit = create_unit(identifier: "101")

    assert_equal "bld-torre-sur-101", unit.code
  end

  test "accented and unaccented identifiers collide in the same context" do
    create_unit(identifier: "Area 4", section_id: @section.id)
    result = build_unit(identifier: "Área 4", section_id: @section.id)

    assert result.invalid?
    assert_includes result.errors[:identifier],
                    I18n.t("frontend.admin.units.validations.identifier_taken")
  end

  test "unit keeps its code after moving to another section" do
    other = @property.property_sections.create!(
      organization: @organization, name: "Torre B", section_type: SectionTypes::TOWER,
      code: "bld-torre-sur-tor-torre-b"
    )
    unit = create_unit(identifier: "101", section_id: @section.id)
    original_code = unit.code

    result = Units::MoveToSection.call(actor: @actor, unit: unit, section_id: other.id)

    assert result.unit.property_section_id == other.id
    assert_equal original_code, result.unit.reload.code
  end

  private

  def build_unit(identifier:, section_id: nil)
    Units::Create.call(
      actor: @actor, property: @property, section_id: section_id,
      attributes: { identifier: identifier, unit_type: UnitTypes::APARTMENT }
    )
  end

  def create_unit(identifier:, section_id: nil)
    result = build_unit(identifier: identifier, section_id: section_id)
    assert result.success?, "expected unit create to succeed: #{result.errors&.full_messages}"
    result.unit
  end
end
