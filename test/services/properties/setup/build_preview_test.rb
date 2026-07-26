# frozen_string_literal: true

require "test_helper"

class Properties::Setup::BuildPreviewTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Preview Property",
      property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::DRAFT,
      address_line: "Main 1",
      city: "Santiago",
      country: "Chile",
      timezone: "America/Santiago",
      metadata: {
        "setup_wizard" => {
          "structure_mode" => "manual",
          "units_mode" => "individual",
          "estimated_units" => 10
        }
      }
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "returns property counts structure tree and unit preview" do
    admin = create_user_for_organization(
      organization: @organization,
      email: "preview-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    section_result = PropertySections::Create.call(
      actor: admin,
      property: @property,
      parent: nil,
      attributes: { name: "Torre A", section_type: SectionTypes::TOWER }
    )
    refute section_result.invalid?, section_result.section&.errors&.full_messages&.join(", ")

    unit_result = Units::Create.call(
      actor: admin,
      property: @property,
      attributes: { identifier: "101", unit_type: UnitTypes::APARTMENT }
    )
    refute unit_result.invalid?, unit_result.unit&.errors&.full_messages&.join(", ")

    preview = Properties::Setup::BuildPreview.call(property: @property.reload, actor: admin)

    assert_equal "Preview Property", preview.dig(:property, :name)
    assert_equal 1, preview.dig(:counts, :sections)
    assert_equal 1, preview.dig(:counts, :units)
    assert_equal 1, preview.dig(:structure, :tree).size
    assert_equal "101", preview[:units].first[:identifier]
  end

  test "does not flag missing units in automatic mode before generation" do
    @property.update!(
      metadata: {
        "setup_wizard" => {
          "structure_mode" => "quick",
          "units_mode" => "automatic"
        }
      }
    )

    preview = Properties::Setup::BuildPreview.call(property: @property)

    refute_includes preview[:blocking_errors], I18n.t("frontend.admin.property_setup.step3.errors.no_units")
  end

  test "flags blocking errors when manual structure is empty" do
    preview = Properties::Setup::BuildPreview.call(property: @property)

    assert_includes preview[:blocking_errors], I18n.t("frontend.admin.property_setup.step2.errors.manual_empty")
  end

  # fix-automatic-unit-generation §8: structure counts are format-aware.
  def draft_property(property_type)
    ResidentialProperty.create!(
      organization: @organization,
      name: "Counts #{property_type} #{SecureRandom.hex(3)}",
      property_type: property_type,
      status: PropertyStatuses::DRAFT,
      country: "Chile",
      timezone: "America/Santiago"
    )
  end

  test "condominium reports non-zero level_1 (sectors) and level_2 (blocks)" do
    admin = create_user_for_organization(
      organization: @organization, email: "counts-condo@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    property = draft_property(PropertyTypes::CONDOMINIUM)
    Properties::Setup::ApplyQuickStructure.call(
      actor: admin, property: property,
      params: { level_1_count: 2, level_2_count: 3, level_1_prefix: "Sector", level_2_prefix: "Bloque" }
    )

    counts = Properties::Setup::BuildPreview.call(property: property.reload, actor: admin)[:counts]

    assert_equal 2, counts[:level_1]
    assert_equal 6, counts[:level_2]
  end

  test "single-level sector counts blocks in level_1 only, not duplicated in level_2" do
    admin = create_user_for_organization(
      organization: @organization, email: "counts-sector@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    property = draft_property(PropertyTypes::SECTOR)
    Properties::Setup::ApplyQuickStructure.call(
      actor: admin, property: property, params: { level_1_count: 4, level_1_prefix: "Bloque" }
    )

    counts = Properties::Setup::BuildPreview.call(property: property.reload, actor: admin)[:counts]

    assert_equal 4, counts[:level_1]
    assert_equal 0, counts[:level_2]
  end

  test "counts.units matches 24 persisted non-deleted section-associated units" do
    admin = create_user_for_organization(
      organization: @organization, email: "counts-24@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    section = PropertySections::Create.call(
      actor: admin, property: @property, parent: nil,
      attributes: { name: "Torre A", section_type: SectionTypes::TOWER }
    ).section

    24.times do |i|
      Units::Create.call(
        actor: admin, property: @property, section_id: section.id,
        attributes: { identifier: format("%03d", i + 1), unit_type: UnitTypes::APARTMENT }
      )
    end

    preview = Properties::Setup::BuildPreview.call(property: @property.reload, actor: admin)

    assert_equal 24, preview.dig(:counts, :units)
  end

  test "property_summary does not expose an estimated_units key" do
    preview = Properties::Setup::BuildPreview.call(property: @property)

    refute preview[:property].key?(:estimated_units)
  end

  test "excludes soft-deleted units from counts and nested preview" do
    admin = create_user_for_organization(
      organization: @organization, email: "counts-soft-deleted@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    section = PropertySections::Create.call(
      actor: admin, property: @property, parent: nil,
      attributes: { name: "Torre A", section_type: SectionTypes::TOWER }
    ).section
    kept = Units::Create.call(
      actor: admin, property: @property, section_id: section.id,
      attributes: { identifier: "101", unit_type: UnitTypes::APARTMENT }
    ).unit
    removed = Units::Create.call(
      actor: admin, property: @property, section_id: section.id,
      attributes: { identifier: "102", unit_type: UnitTypes::APARTMENT }
    ).unit
    Units::SoftDelete.call(actor: admin, unit: removed)

    preview = Properties::Setup::BuildPreview.call(property: @property.reload, actor: admin)

    assert_equal 1, preview.dig(:counts, :units)
    assert_equal [ kept.id ], preview[:units].map { |row| row[:id] }
  end

  test "soft-deleting one of several persisted units reduces the total by one" do
    admin = create_user_for_organization(
      organization: @organization, email: "counts-reduce@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    section = PropertySections::Create.call(
      actor: admin, property: @property, parent: nil,
      attributes: { name: "Torre A", section_type: SectionTypes::TOWER }
    ).section
    units = 3.times.map do |i|
      Units::Create.call(
        actor: admin, property: @property, section_id: section.id,
        attributes: { identifier: format("%03d", i + 1), unit_type: UnitTypes::APARTMENT }
      ).unit
    end

    assert_equal 3, Properties::Setup::BuildPreview.call(property: @property.reload, actor: admin).dig(:counts, :units)

    Units::SoftDelete.call(actor: admin, unit: units.first)

    assert_equal 2, Properties::Setup::BuildPreview.call(property: @property.reload, actor: admin).dig(:counts, :units)
  end

  test "excludes units whose section was soft-deleted, even when the unit itself is not" do
    admin = create_user_for_organization(
      organization: @organization, email: "counts-deleted-section@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    kept_section = PropertySections::Create.call(
      actor: admin, property: @property, parent: nil,
      attributes: { name: "Torre A", section_type: SectionTypes::TOWER }
    ).section
    kept_unit = Units::Create.call(
      actor: admin, property: @property, section_id: kept_section.id,
      attributes: { identifier: "101", unit_type: UnitTypes::APARTMENT }
    ).unit

    removed_section = PropertySections::Create.call(
      actor: admin, property: @property, parent: nil,
      attributes: { name: "Torre B", section_type: SectionTypes::TOWER }
    ).section
    orphaned_unit = Units::Create.call(
      actor: admin, property: @property, section_id: removed_section.id,
      attributes: { identifier: "201", unit_type: UnitTypes::APARTMENT }
    ).unit
    # Bypasses PropertySection's `dependent: :restrict_with_error` on units, simulating
    # a section soft-deleted while non-deleted units still reference it (legacy/edge
    # data state the backend must still defend against).
    removed_section.update_column(:deleted_at, Time.current)

    preview = Properties::Setup::BuildPreview.call(property: @property.reload, actor: admin)

    assert_equal 1, preview.dig(:counts, :units)
    assert_equal [ kept_unit.id ], preview[:units].map { |row| row[:id] }
    refute_includes preview[:units].map { |row| row[:id] }, orphaned_unit.id
  end

  test "excludes an archived section and its units from counts and the tree" do
    admin = create_user_for_organization(
      organization: @organization, email: "counts-archived-section@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    kept_section = PropertySections::Create.call(
      actor: admin, property: @property, parent: nil,
      attributes: { name: "Torre A", section_type: SectionTypes::TOWER }
    ).section
    kept_unit = Units::Create.call(
      actor: admin, property: @property, section_id: kept_section.id,
      attributes: { identifier: "101", unit_type: UnitTypes::APARTMENT }
    ).unit

    archived_section = PropertySections::Create.call(
      actor: admin, property: @property, parent: nil,
      attributes: { name: "Torre B", section_type: SectionTypes::TOWER }
    ).section
    Units::Create.call(
      actor: admin, property: @property, section_id: archived_section.id,
      attributes: { identifier: "201", unit_type: UnitTypes::APARTMENT }
    )
    PropertySections::Archive.call(actor: admin, section: archived_section)

    preview = Properties::Setup::BuildPreview.call(property: @property.reload, actor: admin)

    assert_equal 1, preview.dig(:counts, :units)
    assert_equal 1, preview.dig(:counts, :sections)
    assert_equal [ kept_unit.id ], preview[:units].map { |row| row[:id] }
    assert_equal [ "Torre A" ], preview.dig(:structure, :tree).map { |node| node[:name] }
  end

  test "excludes a directly archived unit under a non-archived section" do
    admin = create_user_for_organization(
      organization: @organization, email: "counts-archived-unit@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    section = PropertySections::Create.call(
      actor: admin, property: @property, parent: nil,
      attributes: { name: "Torre A", section_type: SectionTypes::TOWER }
    ).section
    kept_unit = Units::Create.call(
      actor: admin, property: @property, section_id: section.id,
      attributes: { identifier: "101", unit_type: UnitTypes::APARTMENT }
    ).unit
    archived_unit = Units::Create.call(
      actor: admin, property: @property, section_id: section.id,
      attributes: { identifier: "102", unit_type: UnitTypes::APARTMENT }
    ).unit
    Units::Archive.call(actor: admin, unit: archived_unit)

    preview = Properties::Setup::BuildPreview.call(property: @property.reload, actor: admin)

    assert_equal 1, preview.dig(:counts, :units)
    assert_equal [ kept_unit.id ], preview[:units].map { |row| row[:id] }
    assert_equal 1, preview.dig(:counts, :sections)
  end

  test "excludes units and sections belonging to another property" do
    admin = create_user_for_organization(
      organization: @organization, email: "counts-other-property@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    other_property = draft_property(PropertyTypes::BUILDING)
    other_section = PropertySections::Create.call(
      actor: admin, property: other_property, parent: nil,
      attributes: { name: "Otra torre", section_type: SectionTypes::TOWER }
    ).section
    Units::Create.call(
      actor: admin, property: other_property, section_id: other_section.id,
      attributes: { identifier: "999", unit_type: UnitTypes::APARTMENT }
    )

    section = PropertySections::Create.call(
      actor: admin, property: @property, parent: nil,
      attributes: { name: "Torre A", section_type: SectionTypes::TOWER }
    ).section
    Units::Create.call(
      actor: admin, property: @property, section_id: section.id,
      attributes: { identifier: "101", unit_type: UnitTypes::APARTMENT }
    )

    preview = Properties::Setup::BuildPreview.call(property: @property.reload, actor: admin)

    assert_equal 1, preview.dig(:counts, :units)
    assert_equal 1, preview.dig(:counts, :sections)
  end

  test "excludes properties, sections, and units from another organization" do
    admin = create_user_for_organization(
      organization: @organization, email: "counts-other-org@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    section = PropertySections::Create.call(
      actor: admin, property: @property, parent: nil,
      attributes: { name: "Torre A", section_type: SectionTypes::TOWER }
    ).section
    Units::Create.call(
      actor: admin, property: @property, section_id: section.id,
      attributes: { identifier: "101", unit_type: UnitTypes::APARTMENT }
    )

    ActsAsTenant.with_tenant(organizations(:two)) do
      other_org = organizations(:two)
      other_property = ResidentialProperty.create!(
        organization: other_org, name: "Other Org Property", property_type: PropertyTypes::BUILDING,
        status: PropertyStatuses::DRAFT, country: "Chile", timezone: "America/Santiago"
      )
      other_admin = create_user_for_organization(
        organization: other_org, email: "counts-other-org-admin@example.test", role: AvailableRoles::TENANT_ADMIN
      )
      other_section = PropertySections::Create.call(
        actor: other_admin, property: other_property, parent: nil,
        attributes: { name: "Otra org torre", section_type: SectionTypes::TOWER }
      ).section
      Units::Create.call(
        actor: other_admin, property: other_property, section_id: other_section.id,
        attributes: { identifier: "999", unit_type: UnitTypes::APARTMENT }
      )
    end

    preview = Properties::Setup::BuildPreview.call(property: @property.reload, actor: admin)

    assert_equal 1, preview.dig(:counts, :units)
    assert_equal 1, preview.dig(:counts, :sections)
  end

  test "unit preview row shows the derived code, not the raw identifier" do
    admin = create_user_for_organization(
      organization: @organization, email: "counts-code@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    section = PropertySections::Create.call(
      actor: admin, property: @property, parent: nil,
      attributes: { name: "Torre A", section_type: SectionTypes::TOWER }
    ).section
    unit = Units::Create.call(
      actor: admin, property: @property, section_id: section.id,
      attributes: { identifier: "101", unit_type: UnitTypes::APARTMENT }
    ).unit

    row = Properties::Setup::BuildPreview.call(property: @property.reload, actor: admin)[:units].first

    assert_equal unit.code, row[:code]
    assert_not_equal unit.identifier, row[:code]
  end
end
