# frozen_string_literal: true

require "test_helper"

class Properties::Setup::ApplyAutomaticUnitsTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @admin = create_user_for_organization(
      organization: @organization,
      email: "apply-auto@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  def draft_property(property_type)
    ResidentialProperty.create!(
      organization: @organization,
      name: "Auto #{property_type} #{SecureRandom.hex(3)}",
      property_type: property_type,
      status: PropertyStatuses::DRAFT,
      country: "Chile",
      timezone: "America/Santiago"
    )
  end

  def building_with_structure(towers:, floors:)
    property = draft_property(PropertyTypes::BUILDING)
    Properties::Setup::ApplyQuickStructure.call(
      actor: @admin, property: property,
      params: { level_1_count: towers, level_2_count: floors, level_1_prefix: "Torre", level_2_prefix: "Piso" }
    )
    property.reload
  end

  def sector_with_blocks(count)
    property = draft_property(PropertyTypes::SECTOR)
    Properties::Setup::ApplyQuickStructure.call(
      actor: @admin, property: property, params: { level_1_count: count, level_1_prefix: "Bloque" }
    )
    property.reload
  end

  test "distributes units per leaf section, none unsectioned" do
    property = building_with_structure(towers: 2, floors: 3)

    result = Properties::Setup::ApplyAutomaticUnits.call(
      actor: @admin, property: property,
      params: { units_per_leaf: 4, identifier_format: "floor_sequential", unit_type: UnitTypes::APARTMENT }
    )

    assert result.success?, property.errors.full_messages.join(", ")
    property.reload
    assert_equal 24, property.units.count
    assert property.units.all? { |u| u.property_section_id.present? }
    floor_ids = property.property_sections.where(section_type: SectionTypes::FLOOR).pluck(:id)
    floor_ids.each { |fid| assert_equal 4, property.units.where(property_section_id: fid).count }
  end

  test "honors configured unit_type and block_sequential identifiers per block position" do
    property = sector_with_blocks(2)
    blocks = property.property_sections.where(section_type: SectionTypes::BLOCK).order(:position)

    result = Properties::Setup::ApplyAutomaticUnits.call(
      actor: @admin, property: property,
      params: { units_per_leaf: 2, identifier_format: "block_sequential", unit_type: UnitTypes::OFFICE }
    )

    assert result.success?, property.errors.full_messages.join(", ")
    property.reload
    assert property.units.all? { |u| u.unit_type == UnitTypes::OFFICE }
    assert_equal %w[B101 B102], property.units.where(property_section_id: blocks.first.id).order(:identifier).pluck(:identifier)
    assert_equal %w[B201 B202], property.units.where(property_section_id: blocks.second.id).order(:identifier).pluck(:identifier)
  end

  test "uses the configured per-leaf quantity, not a flat total" do
    property = building_with_structure(towers: 1, floors: 2)

    Properties::Setup::ApplyAutomaticUnits.call(
      actor: @admin, property: property, params: { units_per_leaf: 5 }
    )

    property.reload
    assert_equal 10, property.units.count
  end

  test "is unavailable and invalid when no format resolves" do
    property = draft_property(PropertyTypes::OTHER)

    result = Properties::Setup::ApplyAutomaticUnits.call(
      actor: @admin, property: property, params: { units_per_leaf: 4 }
    )

    assert result.invalid?
    assert_equal 0, property.units.count
    assert_includes property.errors.details[:base].map { |e| e[:error] }, :automatic_generation_unavailable
  end

  test "a mid-batch Units::Create failure is reported as invalid, not silent success" do
    property = sector_with_blocks(2)
    blocks = property.property_sections.where(section_type: SectionTypes::BLOCK).order(:position)
    # Make the second leaf non-operative so its units cannot be created.
    blocks.second.update!(status: SectionStatuses::INACTIVE)

    result = Properties::Setup::ApplyAutomaticUnits.call(
      actor: @admin, property: property.reload,
      params: { units_per_leaf: 2, identifier_format: "block_sequential" }
    )

    assert result.invalid?
    # The failure stops the batch; not all planned units were created.
    assert_operator property.reload.units.count, :<, 4
  end

  test "re-running fills only missing units and does not duplicate" do
    property = building_with_structure(towers: 1, floors: 2)
    params = { units_per_leaf: 4, identifier_format: "floor_sequential" }

    Properties::Setup::ApplyAutomaticUnits.call(actor: @admin, property: property, params: params)
    assert_equal 8, property.reload.units.count

    result = Properties::Setup::ApplyAutomaticUnits.call(actor: @admin, property: property.reload, params: params)
    assert result.success?
    assert_equal 8, property.reload.units.count
  end

  test "records a non-blocking warning when an existing unit has a different type" do
    property = sector_with_blocks(1)
    block = property.property_sections.find_by(section_type: SectionTypes::BLOCK)

    # Pre-seed B101 as an apartment; regenerate as offices.
    Units::Create.call(
      actor: @admin, property: property, section_id: block.id,
      attributes: { identifier: "B101", unit_type: UnitTypes::APARTMENT }
    )

    service = Properties::Setup::ApplyAutomaticUnits.new(
      actor: @admin, property: property.reload,
      params: { units_per_leaf: 1, identifier_format: "block_sequential", unit_type: UnitTypes::OFFICE }
    )
    result = service.call

    assert result.success?
    assert_equal 1, property.reload.units.count
    assert_equal UnitTypes::APARTMENT, property.units.first.unit_type
    assert_equal 1, service.warnings.size
    assert_equal "B101", service.warnings.first[:identifier]
  end
end
