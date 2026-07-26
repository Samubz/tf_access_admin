# frozen_string_literal: true

require "test_helper"

module BulkImportServices
  class ImportUnitsRowTest < ActiveSupport::TestCase
    include OperationalPolicyTestHelper

    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization
      @tenant_admin = create_user_for_organization(
        organization: @organization,
        email: "import-units-row-admin@example.test",
        role: AvailableRoles::TENANT_ADMIN
      )
      @property = create_property(@organization, "Import Units Row Property")
      @section = @property.property_sections.create!(
        organization: @organization,
        name: "Piso 1",
        section_type: SectionTypes::FLOOR
      )
      @other_section = @property.property_sections.create!(
        organization: @organization,
        name: "Piso 2",
        section_type: SectionTypes::FLOOR
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    test "create mode imports a new unit through the canonical service boundary" do
      bulk_import = build_bulk_import("create_only")
      row = build_row(
        bulk_import,
        unit_identifier: "NEW-101",
        unit_type: UnitTypes::APARTMENT,
        display_name: "Imported Unit"
      )

      assert_difference -> { @property.units.count }, 1 do
        result = ImportUnitsRow.call(row:, bulk_import:)
        assert_equal :imported, result
      end

      unit = @property.units.find_by(identifier: "NEW-101")
      assert_equal "Imported Unit", unit.display_name
      assert_equal "new-101", unit.normalized_identifier
      assert_equal "imported", row.reload.import_status
    end

    test "update_only applies descriptive changes through Units::Update" do
      unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        property_section: @section,
        identifier: "UPD-101",
        unit_type: UnitTypes::APARTMENT
      )
      bulk_import = build_bulk_import("update_only")
      row = build_row(
        bulk_import,
        unit_identifier: "UPD-101",
        unit_type: UnitTypes::APARTMENT,
        display_name: "Updated Name",
        status: UnitStatuses::MAINTENANCE,
        target_unit_id: unit.id,
        operation: "update"
      )

      result = ImportUnitsRow.call(row:, bulk_import:)
      assert_equal :imported, result
      assert_equal UnitStatuses::MAINTENANCE, unit.reload.status
      assert_equal "Updated Name", unit.display_name
    end

    test "update_only moves placement when the target section differs" do
      unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        property_section: @section,
        identifier: "MOV-101",
        unit_type: UnitTypes::APARTMENT
      )
      bulk_import = build_bulk_import("update_only", property_section: @other_section)
      row = build_row(
        bulk_import,
        unit_identifier: "MOV-101",
        unit_type: UnitTypes::APARTMENT,
        target_unit_id: unit.id,
        operation: "update",
        placement_change_requested: true,
        property_section_id: @other_section.id
      )

      result = ImportUnitsRow.call(row:, bulk_import:)
      assert_equal :imported, result
      assert_equal @other_section.id, unit.reload.property_section_id
    end

    test "create_skip_duplicates does not update an existing unit" do
      unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        property_section: @section,
        identifier: "DUP-101",
        unit_type: UnitTypes::APARTMENT,
        display_name: "Original"
      )
      bulk_import = build_bulk_import("create_skip_duplicates")
      row = build_row(
        bulk_import,
        unit_identifier: "DUP-101",
        unit_type: UnitTypes::APARTMENT,
        display_name: "Should Not Apply",
        validation_status: BulkImportRow::VALIDATION_STATUSES[:warning]
      )

      assert_no_difference -> { @property.units.count } do
        ImportUnitsRow.call(row:, bulk_import:)
      end

      assert_equal "Original", unit.reload.display_name
    end

    test "non-update import modes do not move placement even when flagged" do
      unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        property_section: @section,
        identifier: "NO-MOVE-1",
        unit_type: UnitTypes::APARTMENT
      )
      bulk_import = build_bulk_import("create_skip_duplicates")
      row = build_row(
        bulk_import,
        unit_identifier: "NO-MOVE-1",
        unit_type: UnitTypes::APARTMENT,
        placement_change_requested: true,
        property_section_id: @other_section.id
      )

      ImportUnitsRow.call(row:, bulk_import:)

      assert_equal @section.id, unit.reload.property_section_id
    end

    test "validator ignores spreadsheet normalized_identifier" do
      bulk_import = build_bulk_import("create_only")
      context = UnitsImportValidationContext.new(bulk_import:)
      parsed_row = UnitsSpreadsheetReader::ParsedRow.new(
        row_number: 2,
        raw_payload: {
          "unit_identifier" => "Torre A 101",
          "normalized_identifier" => "forged-value",
          "unit_type" => UnitTypes::APARTMENT
        }
      )

      result = UnitsImportRowValidator.call(parsed_row:, context:)

      assert_nil result.normalized_payload["normalized_identifier"]
    end

    test "update_only rejects target_unit_id from another property in the same organization" do
      other_property = create_property(@organization, "Other Property")
      other_section = other_property.property_sections.create!(
        organization: @organization,
        name: "Piso 1",
        section_type: SectionTypes::FLOOR
      )
      unit = Unit.create!(
        organization: @organization,
        residential_property: other_property,
        property_section: other_section,
        identifier: "CROSS-PROP-101",
        unit_type: UnitTypes::APARTMENT
      )

      bulk_import = build_bulk_import("update_only")
      row = build_row(
        bulk_import,
        unit_identifier: "CROSS-PROP-101",
        target_unit_id: unit.id,
        operation: "update"
      )

      result = ImportUnitsRow.call(row:, bulk_import:)
      assert_equal :failed, result

      row.reload
      assert_equal "failed", row.import_status
      assert_match(/does not exist in this section/i, row.failure_message)
    end

    test "update_only rejects target_unit_id from another organization" do
      other_org = organizations(:two)
      other_property = create_property(other_org, "Other Org Property")
      other_section = other_property.property_sections.create!(
        organization: other_org,
        name: "Piso 1",
        section_type: SectionTypes::FLOOR
      )
      unit = Unit.create!(
        organization: other_org,
        residential_property: other_property,
        property_section: other_section,
        identifier: "CROSS-ORG-101",
        unit_type: UnitTypes::APARTMENT
      )

      bulk_import = build_bulk_import("update_only")
      row = build_row(
        bulk_import,
        unit_identifier: "CROSS-ORG-101",
        target_unit_id: unit.id,
        operation: "update"
      )

      result = ImportUnitsRow.call(row:, bulk_import:)
      assert_equal :failed, result

      row.reload
      assert_equal "failed", row.import_status
      assert_match(/does not exist in this section/i, row.failure_message)
    end

    test "update_only does not modify unit from another property" do
      other_property = create_property(@organization, "Other Property for No Modify")
      other_section = other_property.property_sections.create!(
        organization: @organization,
        name: "Piso 1",
        section_type: SectionTypes::FLOOR
      )
      unit = Unit.create!(
        organization: @organization,
        residential_property: other_property,
        property_section: other_section,
        identifier: "NO-MOD-101",
        unit_type: UnitTypes::APARTMENT,
        display_name: "Original Name",
        status: UnitStatuses::AVAILABLE
      )

      bulk_import = build_bulk_import("update_only")
      row = build_row(
        bulk_import,
        unit_identifier: "NO-MOD-101",
        unit_type: UnitTypes::APARTMENT,
        display_name: "Should Not Apply",
        status: UnitStatuses::MAINTENANCE,
        target_unit_id: unit.id,
        operation: "update"
      )

      ImportUnitsRow.call(row:, bulk_import:)

      unit.reload
      assert_equal "Original Name", unit.display_name
      assert_equal UnitStatuses::AVAILABLE, unit.status
    end

    test "update_only does not create ownership for unit from another property" do
      other_property = create_property(@organization, "Other Property for Ownership")
      other_section = other_property.property_sections.create!(
        organization: @organization,
        name: "Piso 1",
        section_type: SectionTypes::FLOOR
      )
      unit = Unit.create!(
        organization: @organization,
        residential_property: other_property,
        property_section: other_section,
        identifier: "NO-OWN-101",
        unit_type: UnitTypes::APARTMENT
      )

      bulk_import = build_bulk_import("update_only")
      row = build_row(
        bulk_import,
        unit_identifier: "NO-OWN-101",
        target_unit_id: unit.id,
        will_import_ownership: true,
        owner_email: "owner@test.example",
        operation: "update"
      )

      assert_no_difference -> { UnitOwnership.count } do
        ImportUnitsRow.call(row:, bulk_import:)
      end
    end

    test "update_only works correctly with target_unit_id in same property" do
      unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        property_section: @section,
        identifier: "VALID-UPDATE-101",
        unit_type: UnitTypes::APARTMENT,
        display_name: "Original"
      )

      bulk_import = build_bulk_import("update_only")
      row = build_row(
        bulk_import,
        unit_identifier: "DIFFERENT-ID",
        target_unit_id: unit.id,
        display_name: "Updated Name",
        operation: "update"
      )

      result = ImportUnitsRow.call(row:, bulk_import:)
      assert_equal :imported, result

      unit.reload
      assert_equal "Updated Name", unit.display_name
      assert_equal "imported", row.reload.import_status
    end

    test "create mode imports new unit without section" do
      bulk_import = build_bulk_import("create_only", property_section: nil)
      row = build_row(
        bulk_import,
        unit_identifier: "NO-SEC-101",
        unit_type: UnitTypes::APARTMENT,
        display_name: "No Section Unit"
      )

      assert_difference -> { @property.units.where(property_section_id: nil).count }, 1 do
        result = ImportUnitsRow.call(row:, bulk_import:)
        assert_equal :imported, result
      end

      unit = @property.units.find_by(identifier: "NO-SEC-101", property_section_id: nil)
      assert_equal "No Section Unit", unit.display_name
      assert_equal "imported", row.reload.import_status
    end

    test "duplicate detection works for units without section" do
      bulk_import = build_bulk_import("create_only", property_section: nil)
      row1 = build_row(
        bulk_import,
        unit_identifier: "DUP-NO-SEC-1",
        unit_type: UnitTypes::APARTMENT
      )
      row2 = build_row(
        bulk_import,
        unit_identifier: "DUP-NO-SEC-1",
        unit_type: UnitTypes::APARTMENT
      )

      context = UnitsImportValidationContext.new(bulk_import:)
      key1 = context.build_group_key(nil, "DUP-NO-SEC-1")
      key2 = context.build_group_key(nil, "DUP-NO-SEC-1")

      assert_equal key1, key2
      assert key1.present?
      assert_match(/unit:root:/, key1)
    end

    test "update_only finds unit without section" do
      unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        identifier: "UPDATE-NO-SEC",
        unit_type: UnitTypes::APARTMENT,
        property_section: nil,
        status: UnitStatuses::AVAILABLE
      )

      bulk_import = build_bulk_import("update_only", property_section: nil)
      row = build_row(
        bulk_import,
        unit_identifier: "UPDATE-NO-SEC",
        unit_type: UnitTypes::APARTMENT,
        display_name: "Updated No Section",
        operation: "update"
      )

      result = ImportUnitsRow.call(row:, bulk_import:)
      assert_equal :imported, result

      unit.reload
      assert_equal "Updated No Section", unit.display_name
      assert_nil unit.property_section_id
    end

    test "same identifier can exist with and without section" do
      section = @section
      unit_in_section = Unit.create!(
        organization: @organization,
        residential_property: @property,
        property_section: section,
        identifier: "SAME-ID",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )

      bulk_import = build_bulk_import("create_only", property_section: nil)
      row = build_row(
        bulk_import,
        unit_identifier: "SAME-ID",
        unit_type: UnitTypes::APARTMENT
      )

      assert_difference -> { @property.units.count }, 1 do
        result = ImportUnitsRow.call(row:, bulk_import:)
        assert_equal :imported, result
      end

      unit_no_section = @property.units.find_by(identifier: "SAME-ID", property_section_id: nil)
      assert unit_no_section
      assert_not_equal unit_in_section.id, unit_no_section.id
    end

    test "same identifier under different sections can coexist" do
      section2 = @property.property_sections.create!(
        organization: @organization,
        name: "Piso 3",
        section_type: SectionTypes::FLOOR
      )

      unit_in_section1 = Unit.create!(
        organization: @organization,
        residential_property: @property,
        property_section: @section,
        identifier: "SAME-DIFF-SEC",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )

      bulk_import = build_bulk_import("create_only", property_section: section2)
      row = build_row(
        bulk_import,
        unit_identifier: "SAME-DIFF-SEC",
        unit_type: UnitTypes::APARTMENT
      )

      assert_difference -> { @property.units.count }, 1 do
        result = ImportUnitsRow.call(row:, bulk_import:)
        assert_equal :imported, result
      end

      unit_in_section2 = @property.units.find_by(identifier: "SAME-DIFF-SEC", property_section: section2)
      assert unit_in_section2
      assert_not_equal unit_in_section1.id, unit_in_section2.id
    end

    private

    def build_bulk_import(import_mode, property_section: @section)
      BulkImport.create!(
        organization: @organization,
        created_by: @tenant_admin,
        residential_property: @property,
        property_section: property_section,
        import_type: BulkImport::IMPORT_TYPES[:units],
        status: "processing",
        metadata: {
          "options" => {
            "import_mode" => import_mode,
            "property_section_id" => property_section&.id,
            "owner_import_mode" => "ignore"
          },
          "import_execution" => { "import_valid_rows_only" => true }
        }
      )
    end

    def build_row(bulk_import, payload)
      validation_status = payload.delete(:validation_status) || BulkImportRow::VALIDATION_STATUSES[:valid]
      bulk_import.rows.create!(
        row_number: bulk_import.rows.count + 1,
        raw_payload: payload,
        normalized_payload: payload.deep_stringify_keys,
        validation_status: validation_status,
        import_status: BulkImportRow::IMPORT_STATUSES[:pending],
        validation_errors: [],
        validation_warnings: []
      )
    end
  end
end
