# frozen_string_literal: true

require "test_helper"

class Properties::Setup::GenerateUnitsPreviewTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @admin = create_user_for_organization(
      organization: @organization,
      email: "units-preview@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  def draft_property(property_type)
    ResidentialProperty.create!(
      organization: @organization,
      name: "Preview #{property_type} #{SecureRandom.hex(3)}",
      property_type: property_type,
      status: PropertyStatuses::DRAFT,
      country: "Chile",
      timezone: "America/Santiago"
    )
  end

  def sector_with_blocks(count)
    property = draft_property(PropertyTypes::SECTOR)
    Properties::Setup::ApplyQuickStructure.call(
      actor: @admin, property: property, params: { level_1_count: count, level_1_prefix: "Bloque" }
    )
    property.reload
  end

  test "previews block-leaf structures with position-based block_sequential ids" do
    property = sector_with_blocks(2)

    result = Properties::Setup::GenerateUnitsPreview.call(
      property: property, params: { units_per_leaf: 2, identifier_format: "block_sequential" }, per_page: 100
    )

    assert_equal 4, result[:total_units]
    identifiers = result[:rows].map { |r| r[:identifier] }
    assert_includes identifiers, "B101"
    assert_includes identifiers, "B201"
  end

  test "honors units_per_leaf (the previously-dropped param)" do
    property = sector_with_blocks(2)

    result = Properties::Setup::GenerateUnitsPreview.call(
      property: property, params: { units_per_leaf: 6, identifier_format: "block_sequential" }, per_page: 100
    )

    assert_equal 12, result[:total_units]
  end

  test "sequential format resets per leaf" do
    property = sector_with_blocks(2)

    result = Properties::Setup::GenerateUnitsPreview.call(
      property: property, params: { units_per_leaf: 2, identifier_format: "sequential" }, per_page: 100
    )

    assert_equal %w[1 2 1 2], result[:rows].map { |r| r[:identifier] }
  end

  test "returns no rows when the property type has no structure format" do
    property = draft_property(PropertyTypes::OTHER)

    result = Properties::Setup::GenerateUnitsPreview.call(
      property: property, params: { units_per_leaf: 4 }, per_page: 100
    )

    assert_equal 0, result[:total_units]
    assert_empty result[:rows]
  end
end
