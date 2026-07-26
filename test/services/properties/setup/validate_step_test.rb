# frozen_string_literal: true

require "test_helper"

class Properties::Setup::ValidateStepTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Validate Step Property",
      property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::DRAFT,
      address_line: "Addr 1",
      city: "Santiago",
      country: "Chile",
      timezone: "America/Santiago",
      metadata: { "setup_wizard" => { "structure_mode" => "none", "units_mode" => "automatic" } }
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "step 1 does not require an estimated_units param" do
    result = Properties::Setup::ValidateStep.new(
      property: @property,
      step: 1,
      attributes: {
        name: "Validated Property",
        property_type: PropertyTypes::BUILDING,
        address_line: "Addr 1"
      }
    ).call

    assert result[:valid]
    refute result[:errors].key?(:estimated_units)
  end

  test "step 2 passes for none structure mode" do
    result = Properties::Setup::ValidateStep.new(
      property: @property,
      step: 2,
      attributes: { structure_mode: "none" }
    ).call

    assert result[:valid]
  end

  test "step 3 requires units for individual mode" do
    result = Properties::Setup::ValidateStep.new(
      property: @property,
      step: 3,
      attributes: { units_mode: "individual" }
    ).call

    refute result[:valid]
  end

  test "step 3 automatic mode passes when leaf sections of units_in type exist" do
    @property.update!(
      property_type: PropertyTypes::BUILDING,
      metadata: { "setup_wizard" => { "structure_mode" => "quick" } }
    )
    @property.property_sections.create!(
      organization: @organization,
      name: "Piso 1",
      section_type: SectionTypes::FLOOR
    )

    result = Properties::Setup::ValidateStep.new(
      property: @property,
      step: 3,
      attributes: { units_mode: "automatic" }
    ).call

    assert result[:valid]
  end

  test "step 3 automatic mode fails when no leaf sections of units_in type exist" do
    @property.update!(
      property_type: PropertyTypes::BUILDING,
      metadata: { "setup_wizard" => { "structure_mode" => "quick" } }
    )

    result = Properties::Setup::ValidateStep.new(
      property: @property,
      step: 3,
      attributes: { units_mode: "automatic" }
    ).call

    refute result[:valid]
    assert result[:errors].key?(:structure)
  end

  test "generate structure preview paginates nodes" do
    preview = Properties::Setup::GenerateStructurePreview.call(
      params: { towers: 2, floors_per_tower: 3, units_per_floor: 4 },
      page: 1,
      per_page: 5
    )

    assert_equal 5, preview[:nodes].size
    assert_equal 8, preview[:pagination][:total]
    assert_equal 2, preview[:counts][:level_1]
  end

  test "generate units preview paginates rows over leaf sections" do
    admin = create_user_for_organization(
      organization: @organization, email: "vs-units-preview@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    # 1 tower x 3 floors x 4 units_per_leaf = 12 planned units.
    Properties::Setup::ApplyQuickStructure.call(
      actor: admin, property: @property,
      params: { level_1_count: 1, level_2_count: 3, level_1_prefix: "Torre", level_2_prefix: "Piso" }
    )

    preview = Properties::Setup::GenerateUnitsPreview.call(
      property: @property.reload,
      params: { units_per_leaf: 4, identifier_format: "floor_sequential" },
      page: 1,
      per_page: 5
    )

    assert_equal 5, preview[:rows].size
    assert_equal 12, preview[:total_units]
    assert_equal 3, preview[:pagination][:total_pages]
  end
end
