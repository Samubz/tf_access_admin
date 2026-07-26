# frozen_string_literal: true

require "test_helper"

class Properties::Setup::UnitGenerationPlanTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @admin = create_user_for_organization(
      organization: @organization,
      email: "unit-plan@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  def draft_property(property_type)
    ResidentialProperty.create!(
      organization: @organization,
      name: "Plan #{property_type} #{SecureRandom.hex(3)}",
      property_type: property_type,
      status: PropertyStatuses::DRAFT,
      country: "Chile",
      timezone: "America/Santiago"
    )
  end

  # Builds a single-level SECTOR structure with +count+ blocks at positions 1..n.
  def sector_with_blocks(count)
    property = draft_property(PropertyTypes::SECTOR)
    Properties::Setup::ApplyQuickStructure.call(
      actor: @admin, property: property, params: { level_1_count: count, level_1_prefix: "Bloque" }
    )
    property.reload
  end

  def format_for(property)
    Properties::Setup::StructureFormatResolver.for(property_type: property.property_type)
  end

  test "returns one row per unit per leaf, grouped by leaf section" do
    property = sector_with_blocks(3)

    rows = Properties::Setup::UnitGenerationPlan.call(
      property: property,
      format: format_for(property),
      params: { units_per_leaf: 4, identifier_format: "block_sequential", unit_type: UnitTypes::APARTMENT }
    )

    assert_equal 12, rows.size
    assert_equal 3, rows.map { |r| r.property_section.id }.uniq.size
    assert(rows.all? { |r| r.property_section.section_type == SectionTypes::BLOCK })
  end

  test "block_sequential is position-based and starts at B101 for position 1" do
    property = sector_with_blocks(2)
    format = format_for(property)
    blocks = property.property_sections.where(section_type: SectionTypes::BLOCK).order(:position)

    rows = Properties::Setup::UnitGenerationPlan.call(
      property: property, format: format,
      params: { units_per_leaf: 2, identifier_format: "block_sequential" }
    )

    first = rows.select { |r| r.property_section == blocks.first }.map(&:identifier)
    second = rows.select { |r| r.property_section == blocks.second }.map(&:identifier)
    assert_equal %w[B101 B102], first
    assert_equal %w[B201 B202], second
  end

  test "sequential resets to 1 per leaf" do
    property = sector_with_blocks(2)

    rows = Properties::Setup::UnitGenerationPlan.call(
      property: property, format: format_for(property),
      params: { units_per_leaf: 3, identifier_format: "sequential" }
    )

    grouped = rows.group_by { |r| r.property_section.id }.values
    assert grouped.all? { |leaf_rows| leaf_rows.map(&:identifier) == %w[1 2 3] }
  end

  test "floor_sequential is the default format" do
    property = sector_with_blocks(1)
    block = property.property_sections.find_by(section_type: SectionTypes::BLOCK)

    rows = Properties::Setup::UnitGenerationPlan.call(
      property: property, format: format_for(property), params: { units_per_leaf: 2 }
    )

    base = block.position * 100
    assert_equal [ (base + 1).to_s, (base + 2).to_s ], rows.map(&:identifier)
  end

  test "carries the configured unit_type and derived normalized_identifier" do
    property = sector_with_blocks(1)

    rows = Properties::Setup::UnitGenerationPlan.call(
      property: property, format: format_for(property),
      params: { units_per_leaf: 1, unit_type: UnitTypes::OFFICE, identifier_format: "block_sequential" }
    )

    row = rows.first
    assert_equal UnitTypes::OFFICE, row.unit_type
    assert_equal "b101", row.normalized_identifier
  end

  test "unavailable and empty when no format resolves for the property type" do
    property = draft_property(PropertyTypes::OTHER)

    plan = Properties::Setup::UnitGenerationPlan.new(
      property: property, format: format_for(property), params: { units_per_leaf: 4 }
    )

    refute plan.available?
    assert_empty plan.rows
  end

  test "unavailable when the format resolves but no leaf sections exist" do
    property = draft_property(PropertyTypes::SECTOR)

    plan = Properties::Setup::UnitGenerationPlan.new(
      property: property, format: format_for(property), params: { units_per_leaf: 4 }
    )

    refute plan.available?
    assert_empty plan.rows
  end
end
