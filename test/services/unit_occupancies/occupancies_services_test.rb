# frozen_string_literal: true

require "test_helper"

module UnitOccupancies
  module TestHelpers
    module_function

    def validation_key(name)
      "admin.unit_occupancies.validations.#{name}"
    end

    def existing_person_match_message(display_name)
      I18n.t(
        "frontend.admin.unit_occupancies.validations.existing_person_match",
        display_name: display_name
      )
    end
  end

  class CreateTest < ActiveSupport::TestCase
    include TestHelpers

    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization

      @property = ResidentialProperty.create!(
        organization: @organization,
        name: "Occupancy Create Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      @unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        identifier: "OCC-SRV-101",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
      @person = Person.create!(
        organization: @organization,
        display_name: "Occupancy Create Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    test "creates occupancy for existing person" do
      occupancy = Create.call(
        unit: @unit,
        occupancy_params: {
          person_id: @person.id,
          occupancy_type: OccupancyTypes::TENANT,
          can_authorize_visits: true,
          starts_at: Date.current
        },
        actor: nil
      )

      assert occupancy.persisted?
      assert_equal @person.id, occupancy.person_id
      assert_equal OccupancyTypes::TENANT, occupancy.occupancy_type
      assert occupancy.can_authorize_visits
      assert_equal OccupancyStatuses::ACTIVE, occupancy.status
    end

    test "normalizes starts_at to beginning of day and ends_at to end of day" do
      occupancy = Create.call(
        unit: @unit,
        occupancy_params: {
          person_id: @person.id,
          occupancy_type: OccupancyTypes::TENANT,
          starts_at: Date.new(2026, 6, 14),
          ends_at: Date.new(2026, 12, 31)
        },
        actor: nil
      )

      zone = ActiveSupport::TimeZone["America/Santiago"]
      assert_equal zone.local(2026, 6, 14, 0, 0, 0), occupancy.starts_at.in_time_zone(zone)
      assert_in_delta zone.local(2026, 12, 31).end_of_day.to_f, occupancy.ends_at.in_time_zone(zone).to_f, 0.001
    end

    test "rejects duplicate active occupancy for same person and unit" do
      Create.call(
        unit: @unit,
        occupancy_params: {
          person_id: @person.id,
          occupancy_type: OccupancyTypes::TENANT,
          starts_at: Date.current
        },
        actor: nil
      )

      error = assert_raises(ActiveRecord::RecordInvalid) do
        Create.call(
          unit: @unit,
          occupancy_params: {
            person_id: @person.id,
            occupancy_type: OccupancyTypes::FAMILY_MEMBER,
            starts_at: Date.current
          },
          actor: nil
        )
      end

      assert_includes error.record.errors[:person_id], validation_key("duplicate_active_person")
      assert_equal 1, @unit.unit_occupancies.count
    end

    test "rejects invalid date range on create" do
      error = assert_raises(ActiveRecord::RecordInvalid) do
        Create.call(
          unit: @unit,
          occupancy_params: {
            person_id: @person.id,
            occupancy_type: OccupancyTypes::TENANT,
            starts_at: Date.current,
            ends_at: Date.current - 1.day
          },
          actor: nil
        )
      end

      assert_includes error.record.errors[:ends_at], validation_key("ends_at_before_starts_at")
      assert_equal 0, @unit.unit_occupancies.count
    end
  end

  class CreateWithPersonTest < ActiveSupport::TestCase
    include TestHelpers

    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization

      @property = ResidentialProperty.create!(
        organization: @organization,
        name: "Occupancy Create With Person Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      @unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        identifier: "OCC-SRV-201",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    test "creates person and occupancy in one transaction" do
      assert_difference -> { Person.count }, 1 do
        assert_difference -> { UnitOccupancy.count }, 1 do
          occupancy = CreateWithPerson.call(
            unit: @unit,
            occupancy_params: {
              occupancy_type: OccupancyTypes::TENANT,
              starts_at: Date.current,
              can_authorize_visits: true
            },
            person_params: {
              first_name: "New",
              last_name: "Occupant",
              document_number: "11.111.111-1",
              email: "new-occupant@example.test",
              person_type: PersonTypes::NATURAL
            },
            actor: nil
          )

          person = occupancy.person
          assert_equal "New Occupant", person.display_name
          assert_equal "11.111.111-1", person.document_number
          assert_equal "new-occupant@example.test", person.contact_email
          assert person.organization_membership&.active?
          assert occupancy.can_authorize_visits
        end
      end
    end

    test "reuses existing person by document number digest" do
      existing = Person.create!(
        organization: @organization,
        display_name: "Existing Doc Occupant",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE,
        document_number: "22.222.222-2"
      )

      assert_no_difference -> { Person.count } do
        assert_difference -> { UnitOccupancy.count }, 1 do
          occupancy = CreateWithPerson.call(
            unit: @unit,
            occupancy_params: {
              occupancy_type: OccupancyTypes::TENANT,
              starts_at: Date.current
            },
            person_params: {
              display_name: "Duplicate Doc",
              document_number: "22222222-2",
              email: "duplicate-doc@example.test"
            },
            actor: nil
          )

          assert_equal existing, occupancy.person
        end
      end
    end

    test "reuses existing person by normalized email" do
      existing = Person.new(
        organization: @organization,
        display_name: "Existing Email Occupant",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      existing.contact_email = "existing-email-occupant@example.test"
      existing.save!

      assert_no_difference -> { Person.count } do
        assert_difference -> { UnitOccupancy.count }, 1 do
          occupancy = CreateWithPerson.call(
            unit: @unit,
            occupancy_params: {
              occupancy_type: OccupancyTypes::TENANT,
              starts_at: Date.current
            },
            person_params: {
              display_name: "Duplicate Email",
              document_number: "33.333.333-3",
              email: "EXISTING-EMAIL-OCCUPANT@example.test"
            },
            actor: nil
          )

          assert_equal existing, occupancy.person
        end
      end
    end

    test "rolls back person creation when occupancy validation fails" do
      Create.call(
        unit: @unit,
        occupancy_params: {
          person_id: Person.create!(
            organization: @organization,
            display_name: "Existing Occupant",
            person_type: PersonTypes::NATURAL,
            status: PersonStatuses::ACTIVE
          ).id,
          occupancy_type: OccupancyTypes::TENANT,
          starts_at: Date.current
        },
        actor: nil
      )

      assert_no_difference -> { Person.count } do
        assert_no_difference -> { UnitOccupancy.count } do
          assert_raises(ActiveRecord::RecordInvalid) do
            CreateWithPerson.call(
              unit: @unit,
              occupancy_params: {
                occupancy_type: OccupancyTypes::TENANT,
                starts_at: Date.current,
                ends_at: Date.current - 1.day
              },
              person_params: {
                display_name: "Should Roll Back",
                document_number: "44.444.444-4",
                email: "rollback@example.test"
              },
              actor: nil
            )
          end
        end
      end

      assert_nil Person.find_by(display_name: "Should Roll Back")
    end
  end

  class UpdateTest < ActiveSupport::TestCase
    include TestHelpers

    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization

      @property = ResidentialProperty.create!(
        organization: @organization,
        name: "Occupancy Update Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      @unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        identifier: "OCC-SRV-301",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
      @person = Person.create!(
        organization: @organization,
        display_name: "Occupancy Update Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      @occupancy = UnitOccupancy.create!(
        organization: @organization,
        unit: @unit,
        person: @person,
        occupancy_type: OccupancyTypes::TENANT,
        starts_at: Time.zone.parse("2026-06-01 12:00"),
        status: OccupancyStatuses::ACTIVE
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    test "updates occupancy type dates status and visit authorization" do
      updated = Update.call(
        occupancy: @occupancy,
        occupancy_params: {
          occupancy_type: OccupancyTypes::FAMILY_MEMBER,
          can_authorize_visits: true,
          starts_at: Date.new(2026, 6, 10),
          ends_at: Date.new(2026, 12, 31),
          status: OccupancyStatuses::INACTIVE
        },
        actor: nil
      )

      updated.reload
      assert_equal OccupancyTypes::FAMILY_MEMBER, updated.occupancy_type
      assert updated.can_authorize_visits
      assert_equal OccupancyStatuses::INACTIVE, updated.status

      zone = ActiveSupport::TimeZone["America/Santiago"]
      assert_equal zone.local(2026, 6, 10, 0, 0, 0), updated.starts_at.in_time_zone(zone)
      assert_in_delta zone.local(2026, 12, 31).end_of_day.to_f, updated.ends_at.in_time_zone(zone).to_f, 0.001
    end

    test "rejects invalid date range on update" do
      error = assert_raises(ActiveRecord::RecordInvalid) do
        Update.call(
          occupancy: @occupancy,
          occupancy_params: { ends_at: Date.new(2026, 5, 1) },
          actor: nil
        )
      end

      assert_includes error.record.errors[:ends_at], validation_key("ends_at_before_starts_at")
      assert_nil @occupancy.reload.ends_at
    end
  end

  class DestroyTest < ActiveSupport::TestCase
    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization

      @property = ResidentialProperty.create!(
        organization: @organization,
        name: "Occupancy Destroy Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      @unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        identifier: "OCC-SRV-401",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
      @person = Person.create!(
        organization: @organization,
        display_name: "Occupancy Destroy Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      @occupancy = UnitOccupancy.create!(
        organization: @organization,
        unit: @unit,
        person: @person,
        occupancy_type: OccupancyTypes::TENANT,
        starts_at: Time.current,
        status: OccupancyStatuses::ACTIVE
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    test "soft deletes occupancy without hard delete" do
      occupancy_id = @occupancy.id

      Destroy.call(occupancy: @occupancy, actor: nil)

      assert_nil UnitOccupancy.find_by(id: occupancy_id)
      deleted = UnitOccupancy.with_deleted.find(occupancy_id)
      assert deleted.deleted_at.present?
      assert UnitOccupancy.unscoped.exists?(id: occupancy_id)
    end
  end

  class ActiveElsewhereForPersonTest < ActiveSupport::TestCase
    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization

      @property_a = ResidentialProperty.create!(
        organization: @organization,
        name: "Property A",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      @section_a = PropertySection.create!(
        organization: @organization,
        residential_property: @property_a,
        name: "Tower A",
        section_type: SectionTypes::TOWER
      )
      @unit_a = Unit.create!(
        organization: @organization,
        residential_property: @property_a,
        property_section: @section_a,
        identifier: "A-101",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )

      @property_b = ResidentialProperty.create!(
        organization: @organization,
        name: "Property B",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      @unit_b = Unit.create!(
        organization: @organization,
        residential_property: @property_b,
        identifier: "B-202",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )

      @person = Person.create!(
        organization: @organization,
        display_name: "Elsewhere Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )

      @other_occupancy = UnitOccupancy.create!(
        organization: @organization,
        unit: @unit_a,
        person: @person,
        occupancy_type: OccupancyTypes::OWNER_RESIDENT,
        starts_at: Time.zone.parse("2026-06-01 00:00"),
        status: OccupancyStatuses::ACTIVE
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    test "returns active occupancies in other units with property section unit and dates" do
      results = ActiveElsewhereForPerson.call(person: @person, exclude_unit: @unit_b)

      assert_equal 1, results.size
      entry = results.first
      assert_equal @other_occupancy.id, entry[:occupancy_id]
      assert_equal OccupancyTypes::OWNER_RESIDENT, entry[:occupancy_type]
      assert_equal I18n.t("frontend.admin.unit_occupancies.occupancy_types.owner_resident"), entry[:occupancy_type_label]
      assert_equal "A-101", entry.dig(:unit, :identifier)
      assert_equal "Property A", entry.dig(:property, :name)
      assert_equal "Tower A", entry.dig(:property_section, :name)
      assert entry[:starts_at].present?
    end

    test "excludes inactive and expired occupancies elsewhere" do
      @other_occupancy.update!(status: OccupancyStatuses::INACTIVE)

      assert_empty ActiveElsewhereForPerson.call(person: @person, exclude_unit: @unit_b)

      @other_occupancy.update!(
        status: OccupancyStatuses::ACTIVE,
        starts_at: Time.zone.parse("2026-01-01 00:00"),
        ends_at: Time.zone.parse("2026-06-10 23:59:59")
      )

      assert_empty ActiveElsewhereForPerson.call(
        person: @person,
        exclude_unit: @unit_b,
        at: Time.zone.parse("2026-06-14 12:00")
      )
    end
  end

  class ConcurrencyTest < ActiveSupport::TestCase
    include TestHelpers

    self.use_transactional_tests = false

    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization

      @property = ResidentialProperty.create!(
        organization: @organization,
        name: "Occupancy Concurrency Property #{SecureRandom.hex(4)}",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      @unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        identifier: "OCC-SRV-501",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
      @person = Person.create!(
        organization: @organization,
        display_name: "Concurrent Occupant",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
    end

    teardown do
      ActsAsTenant.current_tenant = @organization
      # Clean up relationships to avoid FK violations
      # Tests run in transactions, so units will be cleaned up automatically
      UnitOccupancy.unscoped.where(unit_id: @unit.id).delete_all if @unit
      UnitOwnership.unscoped.where(unit_id: @unit.id).delete_all if @unit
      @person&.destroy
      ActsAsTenant.current_tenant = nil
    end

    test "serializes concurrent creates for same person and unit with unit lock" do
      start_gate = Queue.new
      results = Queue.new

      threads = 2.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ActsAsTenant.current_tenant = @organization
            start_gate.pop
            begin
              Create.call(
                unit: @unit,
                occupancy_params: {
                  person_id: @person.id,
                  occupancy_type: OccupancyTypes::TENANT,
                  starts_at: Date.current
                },
                actor: nil
              )
              results << :success
            rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
              results << :invalid
            end
          end
        end
      end

      2.times { start_gate << true }
      threads.each(&:join)

      outcomes = []
      outcomes << results.pop until results.empty?

      assert_equal 1, outcomes.count(:success)
      assert_equal 1, outcomes.count(:invalid)
      assert_equal 1, @unit.unit_occupancies.count
    end
  end
end
