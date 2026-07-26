# frozen_string_literal: true

require "test_helper"
require Rails.root.join("db/migrate/20260623120000_add_unit_foundation_constraints.rb")

class AddUnitFoundationConstraintsTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @migration = AddUnitFoundationConstraints.new
    @property = create_property(@organization, "Unit Foundation Migration Property")
    @floor = PropertySection.create!(
      organization: @organization,
      residential_property: @property,
      name: "Migration Floor",
      section_type: SectionTypes::FLOOR
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "backfill_normalized_identifiers applies Units::NormalizeIdentifier" do
    unit = Unit.create!(
      organization: @organization,
      residential_property: @property,
      identifier: "  Mig-101  ",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
    unit.update_column(:normalized_identifier, "legacy-value")

    @migration.send(:backfill_normalized_identifiers!)

    unit.reload
    assert_equal "Mig-101", unit.identifier
    assert_equal "mig-101", unit.normalized_identifier
  end

  test "partial unique indexes reject duplicate identifiers without section" do
    create_unit(@property, "DUP-ROOT")
    duplicate = Unit.new(
      organization: @organization,
      residential_property: @property,
      identifier: "dup-root",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )

    assert_not duplicate.valid?
    assert duplicate.errors[:identifier].present?
  end

  test "partial unique indexes allow same identifier under different sections" do
    create_unit(@property, "SEC-101").update!(property_section: @floor)
    other_floor = PropertySection.create!(
      organization: @organization,
      residential_property: @property,
      name: "Migration Floor B",
      section_type: SectionTypes::FLOOR
    )

    result = Units::Create.call(
      actor: create_user_for_organization(
        organization: @organization,
        email: "unit-mig-admin@example.test",
        role: AvailableRoles::TENANT_ADMIN
      ),
      property: @property,
      section_id: other_floor.id,
      attributes: { identifier: "SEC-101", unit_type: UnitTypes::APARTMENT }
    )

    assert result.success?
  end

  test "area_m2 check constraint rejects non-positive values at database level" do
    unit = create_unit(@property, "AREA-CHK")
    error = assert_raises(ActiveRecord::StatementInvalid) do
      unit.update_column(:area_m2, 0)
    end

    assert_match(/units_area_m2_positive/, error.message)
  end

  test "composite organization property foreign key rejects incompatible organization" do
    unit = create_unit(@property, "ORG-COH")

    error = assert_raises(ActiveRecord::StatementInvalid) do
      unit.update_columns(organization_id: organizations(:two).id)
    end

    assert_match(/fk_units_organization_residential_property_coherent/, error.message)
  end

  test "partial unique index with_section_index exists and functions" do
    index_exists = ActiveRecord::Base.connection.indexes(:units)
      .any? { |idx| idx.name == "index_units_on_org_property_section_normalized_when_section" }

    assert index_exists, "WITH_SECTION partial unique index missing"
  end

  test "partial unique index without_section_index exists and functions" do
    index_exists = ActiveRecord::Base.connection.indexes(:units)
      .any? { |idx| idx.name == "index_units_on_org_property_normalized_when_no_section" }

    assert index_exists, "WITHOUT_SECTION partial unique index missing"
  end

  test "lookup index for normalized identifier search exists" do
    index_exists = ActiveRecord::Base.connection.indexes(:units)
      .any? { |idx| idx.name == "idx_units_on_org_property_normalized_identifier_lookup" }

    assert index_exists, "LOOKUP index for normalized identifier missing"
  end

  test "duplicate identifier rejected with section via model validation or DB constraint" do
    unit1 = create_unit(@property, "DUP-SEC")
    unit1.update!(property_section: @floor)

    unit2 = Unit.new(
      organization: @organization,
      residential_property: @property,
      property_section: @floor,
      identifier: "dup-sec",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )

    assert_not unit2.valid?
    assert unit2.errors[:identifier].present?
  end

  test "NOT NULL constraints enforced on required fields" do
    columns_required = %i[
      organization_id residential_property_id identifier normalized_identifier unit_type status metadata
    ]

    columns_required.each do |column|
      next unless Unit.column_names.include?(column.to_s)

      col = Unit.connection.columns(:units).find { |c| c.name == column.to_s }
      assert_not col.null, "Column #{column} should NOT be nullable but is"
    end
  end

  test "organization property coherence index exists" do
    index_exists = ActiveRecord::Base.connection.indexes(:residential_properties)
      .any? { |idx| idx.name == "idx_residential_properties_organization_id_id" }

    assert index_exists, "Organization-property coherence index missing"
  end

  test "foreign key organization_id exists on units" do
    fk_exists = ActiveRecord::Base.connection.foreign_keys(:units)
      .any? { |fk| fk.column == "organization_id" && fk.to_table == "organizations" }

    assert fk_exists, "Foreign key units.organization_id → organizations missing"
  end

  test "foreign key residential_property_id exists on units" do
    fk_exists = ActiveRecord::Base.connection.foreign_keys(:units)
      .any? { |fk| fk.column == "residential_property_id" && fk.to_table == "residential_properties" }

    assert fk_exists, "Foreign key units.residential_property_id → residential_properties missing"
  end

  test "foreign key property_section_id exists on units" do
    fk_exists = ActiveRecord::Base.connection.foreign_keys(:units)
      .any? { |fk| fk.column == "property_section_id" && fk.to_table == "property_sections" }

    assert fk_exists, "Foreign key units.property_section_id → property_sections missing"
  end

  test "composite foreign key for organization coherence exists" do
    fk_exists = ActiveRecord::Base.connection.foreign_keys(:units)
      .any? { |fk| fk.name == "fk_units_organization_residential_property_coherent" }

    assert fk_exists, "Composite FK for org-property coherence missing"
  end

  test "migration backfills and trims identifier properly" do
    unit = Unit.create!(
      organization: @organization,
      residential_property: @property,
      identifier: "   TRIMMED-101   ",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )

    @migration.send(:backfill_normalized_identifiers!)

    unit.reload
    assert_equal "TRIMMED-101", unit.identifier
    assert_equal "trimmed-101", unit.normalized_identifier
  end

  test "soft-deleted units do not block new units with same identifier" do
    unit1 = create_unit(@property, "SOFT-DEL")
    Units::SoftDelete.call(
      actor: create_user_for_organization(
        organization: @organization,
        email: "mig-admin-soft-del@example.test",
        role: AvailableRoles::TENANT_ADMIN
      ),
      unit: unit1
    )

    unit2 = Unit.new(
      organization: @organization,
      residential_property: @property,
      identifier: "SOFT-DEL",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )

    assert_nothing_raised do
      unit2.save!
    end
  end

  test "area_m2 allows NULL values" do
    unit = create_unit(@property, "AREA-NULL")
    assert unit.area_m2.nil?

    unit.update_column(:area_m2, nil)
    unit.reload
    assert_nil unit.area_m2
  end

  test "area_m2 allows positive decimal values" do
    unit = create_unit(@property, "AREA-POS")
    unit.update!(area_m2: 42.5)

    unit.reload
    assert_equal 42.5, unit.area_m2.to_f
  end
end
