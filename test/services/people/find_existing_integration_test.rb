# frozen_string_literal: true

require "test_helper"

module People
  class FindExistingIntegrationTest < ActiveSupport::TestCase
    setup do
      @organization = organizations(:one)
      @other_organization = organizations(:two)
      ActsAsTenant.current_tenant = @organization

      @property = ResidentialProperty.create!(
        organization: @organization,
        name: "Resolution Integration Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      @unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        identifier: "RES-INT-101",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
      @bulk_import = build_bulk_import
      @import_context = BulkImportServices::ImportUnitsImportContext.new(bulk_import: @bulk_import)
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    test "occupancy create reuses existing person by document" do
      existing = create_person!(display_name: "Occupant By Doc", document_number: "11.111.111-1")

      assert_no_difference -> { Person.count } do
        occupancy = UnitOccupancies::CreateWithPerson.call(
          unit: @unit,
          occupancy_params: { occupancy_type: OccupancyTypes::TENANT, starts_at: Date.current },
          person_params: { document_number: "11111111-1", email: "occupant-doc@example.test" },
          actor: nil
        )

        assert_equal existing, occupancy.person
      end
    end

    test "occupancy create reuses existing person by email" do
      existing = create_person_with_email!(display_name: "Occupant By Email", email: "occupant-email@example.test")

      assert_no_difference -> { Person.count } do
        occupancy = UnitOccupancies::CreateWithPerson.call(
          unit: @unit,
          occupancy_params: { occupancy_type: OccupancyTypes::TENANT, starts_at: Date.current },
          person_params: { document_number: "22.222.222-2", email: "occupant-email@example.test" },
          actor: nil
        )

        assert_equal existing, occupancy.person
      end
    end

    test "ownership create reuses existing person by document" do
      existing = create_person!(display_name: "Owner By Doc", document_number: "33.333.333-3")

      assert_no_difference -> { Person.count } do
        ownership = UnitOwnerships::CreateWithPerson.call(
          unit: @unit,
          ownership_params: { ownership_percentage: 100, starts_at: Date.current },
          person_params: { document_number: "33333333-3", email: "owner-doc@example.test" },
          actor: nil
        )

        assert_equal existing, ownership.person
      end
    end

    test "ownership create reuses existing person by email" do
      existing = create_person_with_email!(display_name: "Owner By Email", email: "owner-email@example.test")

      assert_no_difference -> { Person.count } do
        ownership = UnitOwnerships::CreateWithPerson.call(
          unit: @unit,
          ownership_params: { ownership_percentage: 100, starts_at: Date.current },
          person_params: { document_number: "44.444.444-4", email: "owner-email@example.test" },
          actor: nil
        )

        assert_equal existing, ownership.person
      end
    end

    test "bulk import reuses existing person by document" do
      existing = create_person!(display_name: "Import By Doc", document_number: "55.555.555-5")
      normalized = owner_payload(document: "55555555-5", email: "import-doc@example.test")

      assert_no_difference -> { Person.count } do
        person = @import_context.resolve_person!(normalized)

        assert_equal existing, person
      end
    end

    test "bulk import reuses existing person by email" do
      existing = create_person_with_email!(display_name: "Import By Email", email: "import-email@example.test")
      normalized = owner_payload(document: "66.666.666-6", email: "import-email@example.test")

      assert_no_difference -> { Person.count } do
        person = @import_context.resolve_person!(normalized)

        assert_equal existing, person
      end
    end

    test "flows do not reuse person from another organization" do
      other_person = ActsAsTenant.with_tenant(@other_organization) do
        create_person!(
          organization: @other_organization,
          display_name: "Other Org Person",
          document_number: "77.777.777-7"
        )
      end

      assert_difference -> { Person.count }, 1 do
        occupancy = UnitOccupancies::CreateWithPerson.call(
          unit: @unit,
          occupancy_params: { occupancy_type: OccupancyTypes::TENANT, starts_at: Date.current },
          person_params: {
            display_name: "New Org Person",
            document_number: "77777777-7",
            email: "other-org@example.test"
          },
          actor: nil
        )

        refute_equal other_person, occupancy.person
        assert_equal @organization.id, occupancy.person.organization_id
      end
    end

    test "flows do not reuse soft-deleted person" do
      deleted = create_person!(display_name: "Deleted Person", document_number: "88.888.888-8")
      deleted.destroy

      assert_difference -> { Person.count }, 1 do
        ownership = UnitOwnerships::CreateWithPerson.call(
          unit: @unit,
          ownership_params: { ownership_percentage: 100, starts_at: Date.current },
          person_params: {
            display_name: "Replacement Person",
            document_number: "88888888-8",
            email: "deleted-replacement@example.test"
          },
          actor: nil
        )

        refute_equal deleted.id, ownership.person_id
        assert_nil ownership.person.deleted_at
      end
    end

    test "creates new person when no match exists" do
      assert_difference -> { Person.count }, 1 do
        occupancy = UnitOccupancies::CreateWithPerson.call(
          unit: @unit,
          occupancy_params: { occupancy_type: OccupancyTypes::TENANT, starts_at: Date.current },
          person_params: {
            display_name: "Brand New Occupant",
            document_number: "99.999.999-9",
            email: "brand-new@example.test"
          },
          actor: nil
        )

        assert_equal "Brand New Occupant", occupancy.person.display_name
        assert_equal "99.999.999-9", occupancy.person.document_number
      end
    end

    test "owner and occupant flows avoid duplicate people for same identity" do
      existing = create_person!(display_name: "Shared Identity", document_number: "12.345.678-9")

      assert_no_difference -> { Person.count } do
        UnitOwnerships::CreateWithPerson.call(
          unit: @unit,
          ownership_params: { ownership_percentage: 60, starts_at: Date.current },
          person_params: { document_number: "12345678-9", email: "shared@example.test" },
          actor: nil
        )

        other_unit = Unit.create!(
          organization: @organization,
          residential_property: @property,
          identifier: "RES-INT-102",
          unit_type: UnitTypes::APARTMENT,
          status: UnitStatuses::AVAILABLE
        )

        occupancy = UnitOccupancies::CreateWithPerson.call(
          unit: other_unit,
          occupancy_params: { occupancy_type: OccupancyTypes::TENANT, starts_at: Date.current },
          person_params: { document_number: "12345678-9", email: "shared@example.test" },
          actor: nil
        )

        assert_equal existing, occupancy.person
      end
    end

    private

    def create_person!(display_name:, document_number: nil, organization: @organization)
      person = Person.new(
        organization: organization,
        display_name: display_name,
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      person.document_number = document_number if document_number.present?
      person.save!
      person
    end

    def create_person_with_email!(display_name:, email:)
      person = Person.new(
        organization: @organization,
        display_name: display_name,
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      person.contact_email = email
      person.save!
      person
    end

    def owner_payload(document:, email:)
      {
        "owner_document" => document,
        "owner_email" => email,
        "owner_first_name" => "Import",
        "owner_last_name" => "Owner"
      }
    end

    def build_bulk_import
      section = PropertySection.create!(
        organization: @organization,
        residential_property: @property,
        name: "Integration Section",
        section_type: "floor"
      )

      BulkImport.create!(
        organization: @organization,
        created_by: users(:one),
        residential_property: @property,
        property_section: section,
        import_type: BulkImport::IMPORT_TYPES[:units],
        metadata: {
          "options" => {
            "import_mode" => "create_skip_duplicates",
            "property_section_id" => section.id,
            "owner_import_mode" => "create_missing"
          },
          "file_inspection" => { "sheets" => [], "headers" => [], "row_count" => 0 }
        }
      )
    end
  end
end
