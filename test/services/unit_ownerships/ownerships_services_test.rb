# frozen_string_literal: true

require "test_helper"

module UnitOwnerships
  module TestHelpers
    module_function

    def validation_key(name)
      "admin.unit_ownerships.validations.#{name}"
    end

    def existing_person_match_message(display_name)
      I18n.t(
        "frontend.admin.unit_ownerships.validations.existing_person_match",
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
        name: "Create Service Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      @unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        identifier: "SRV-101",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
      @person = Person.create!(
        organization: @organization,
        display_name: "Service Owner",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      @other_person = Person.create!(
        organization: @organization,
        display_name: "Other Owner",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    test "creates ownership for existing person" do
      ownership = Create.call(
        unit: @unit,
        ownership_params: {
          person_id: @person.id,
          ownership_percentage: 40,
          starts_at: Date.current
        },
        actor: nil
      )

      assert ownership.persisted?
      assert_equal @person.id, ownership.person_id
      assert_equal 40, ownership.ownership_percentage.to_i
      assert_equal UnitOwnership::STATUS_ACTIVE, ownership.status
    end

    test "rejects when active ownership percentage exceeds 100 percent cap" do
      Create.call(
        unit: @unit,
        ownership_params: {
          person_id: @person.id,
          ownership_percentage: 60,
          starts_at: Date.current
        },
        actor: nil
      )

      error = assert_raises(ActiveRecord::RecordInvalid) do
        Create.call(
          unit: @unit,
          ownership_params: {
            person_id: @other_person.id,
            ownership_percentage: 50,
            starts_at: Date.current
          },
          actor: nil
        )
      end

      assert_includes error.record.errors[:ownership_percentage], validation_key("percentage_sum_exceeded")
      assert_equal 1, @unit.unit_ownerships.count
    end

    test "rejects duplicate active ownership for same person and unit" do
      Create.call(
        unit: @unit,
        ownership_params: {
          person_id: @person.id,
          ownership_percentage: 40,
          starts_at: Date.current
        },
        actor: nil
      )

      error = assert_raises(ActiveRecord::RecordInvalid) do
        Create.call(
          unit: @unit,
          ownership_params: {
            person_id: @person.id,
            ownership_percentage: 30,
            starts_at: Date.current
          },
          actor: nil
        )
      end

      assert_includes error.record.errors[:person_id], validation_key("duplicate_active_person")
      assert_equal 1, @unit.unit_ownerships.count
    end

    test "rejects invalid date range on create" do
      error = assert_raises(ActiveRecord::RecordInvalid) do
        Create.call(
          unit: @unit,
          ownership_params: {
            person_id: @person.id,
            ownership_percentage: 40,
            starts_at: Date.current,
            ends_at: Date.current - 1.day
          },
          actor: nil
        )
      end

      assert_includes error.record.errors[:ends_at], validation_key("ends_at_before_starts_at")
      assert_equal 0, @unit.unit_ownerships.count
    end
  end

  class CreateWithPersonTest < ActiveSupport::TestCase
    include TestHelpers
    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization

      @property = ResidentialProperty.create!(
        organization: @organization,
        name: "Create With Person Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      @unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        identifier: "SRV-201",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    test "creates person and ownership in one transaction" do
      assert_difference -> { Person.count }, 1 do
        assert_difference -> { UnitOwnership.count }, 1 do
          ownership = CreateWithPerson.call(
            unit: @unit,
            ownership_params: { ownership_percentage: 100, starts_at: Date.current },
            person_params: {
              first_name: "New",
              last_name: "Owner",
              document_number: "11.111.111-1",
              email: "new-owner@example.test",
              person_type: PersonTypes::NATURAL
            },
            actor: nil
          )

          person = ownership.person
          assert_equal "New Owner", person.display_name
          assert_equal "New", person.first_name
          assert_equal "Owner", person.last_name
          assert_equal "11.111.111-1", person.document_number
          assert_equal "new-owner@example.test", person.contact_email
          assert person.organization_membership&.active?
        end
      end
    end

    test "reuses existing person by document number digest" do
      existing = Person.create!(
        organization: @organization,
        display_name: "Existing Doc Owner",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE,
        document_number: "22.222.222-2"
      )

      assert_no_difference -> { Person.count } do
        assert_difference -> { UnitOwnership.count }, 1 do
          ownership = CreateWithPerson.call(
            unit: @unit,
            ownership_params: { ownership_percentage: 100, starts_at: Date.current },
            person_params: {
              display_name: "Duplicate Doc",
              document_number: "22222222-2",
              email: "duplicate-doc@example.test"
            },
            actor: nil
          )

          assert_equal existing, ownership.person
        end
      end
    end

    test "reuses existing person by normalized email linked to user" do
      user = ActsAsTenant.without_tenant do
        User.create!(
          email: "linked-owner@example.test",
          password: "Password1@",
          password_confirmation: "Password1@",
          name: "Linked Owner",
          dni: SecureRandom.hex(4),
          language: Languages::ES,
          confirmed_at: Time.current
        )
      end
      existing = Person.create!(
        organization: @organization,
        user: user,
        display_name: "Linked Owner",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      OrganizationMembership.create!(organization: @organization, person: existing).accept!

      assert_no_difference -> { Person.count } do
        assert_difference -> { UnitOwnership.count }, 1 do
          ownership = CreateWithPerson.call(
            unit: @unit,
            ownership_params: { ownership_percentage: 100, starts_at: Date.current },
            person_params: {
              display_name: "Duplicate Email",
              document_number: "33.333.333-3",
              email: "LINKED-OWNER@example.test"
            },
            actor: nil
          )

          assert_equal existing, ownership.person
        end
      end
    end

    test "rolls back person creation when ownership validation fails" do
      Person.create!(
        organization: @organization,
        display_name: "Cap Owner",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      ).tap do |person|
        UnitOwnership.create!(
          organization: @organization,
          unit: @unit,
          person: person,
          ownership_percentage: 100,
          starts_at: Date.current,
          status: UnitOwnership::STATUS_ACTIVE
        )
      end

      assert_no_difference -> { Person.count } do
        assert_no_difference -> { UnitOwnership.count } do
          assert_raises(ActiveRecord::RecordInvalid) do
            CreateWithPerson.call(
              unit: @unit,
              ownership_params: { ownership_percentage: 10, starts_at: Date.current },
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
        name: "Update Service Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      @unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        identifier: "SRV-301",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
      @person = Person.create!(
        organization: @organization,
        display_name: "Update Owner",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      @other_person = Person.create!(
        organization: @organization,
        display_name: "Other Update Owner",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      @ownership = UnitOwnership.create!(
        organization: @organization,
        unit: @unit,
        person: @person,
        ownership_percentage: 40,
        starts_at: Date.current,
        status: UnitOwnership::STATUS_ACTIVE
      )
      UnitOwnership.create!(
        organization: @organization,
        unit: @unit,
        person: @other_person,
        ownership_percentage: 40,
        starts_at: Date.current,
        status: UnitOwnership::STATUS_ACTIVE
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    test "updates ownership percentage within cap" do
      updated = Update.call(
        ownership: @ownership,
        ownership_params: { ownership_percentage: 50 },
        actor: nil
      )

      assert_equal 50, updated.reload.ownership_percentage.to_i
    end

    test "rejects update when percentage exceeds 100 percent cap" do
      error = assert_raises(ActiveRecord::RecordInvalid) do
        Update.call(
          ownership: @ownership,
          ownership_params: { ownership_percentage: 70 },
          actor: nil
        )
      end

      assert_includes error.record.errors[:ownership_percentage], validation_key("percentage_sum_exceeded")
      assert_equal 40, @ownership.reload.ownership_percentage.to_i
    end

    test "rejects invalid date range" do
      error = assert_raises(ActiveRecord::RecordInvalid) do
        Update.call(
          ownership: @ownership,
          ownership_params: { ends_at: Date.current - 1.day },
          actor: nil
        )
      end

      assert_includes error.record.errors[:ends_at], validation_key("ends_at_before_starts_at")
      assert_nil @ownership.reload.ends_at
    end
  end

  class DestroyTest < ActiveSupport::TestCase
    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization

      @property = ResidentialProperty.create!(
        organization: @organization,
        name: "Destroy Service Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      @unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        identifier: "SRV-401",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
      @person = Person.create!(
        organization: @organization,
        display_name: "Destroy Owner",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      @ownership = UnitOwnership.create!(
        organization: @organization,
        unit: @unit,
        person: @person,
        ownership_percentage: 100,
        starts_at: Date.current,
        status: UnitOwnership::STATUS_ACTIVE
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    test "soft deletes ownership without hard delete" do
      ownership_id = @ownership.id

      Destroy.call(ownership: @ownership, actor: nil)

      assert_nil UnitOwnership.find_by(id: ownership_id)

      deleted = UnitOwnership.with_deleted.find(ownership_id)
      assert deleted.deleted_at.present?
      assert UnitOwnership.unscoped.exists?(id: ownership_id)
    end

    test "soft deleted ownership is excluded from active stats and default scope" do
      ownership_id = @ownership.id
      stats_before = Unit::OwnershipStats.for(@unit)

      assert_equal 1, stats_before[:active_owners_count]
      assert_in_delta 100.0, stats_before[:assigned_percentage]
      assert_in_delta 0.0, stats_before[:available_percentage]

      Destroy.call(ownership: @ownership, actor: nil)

      stats_after = Unit::OwnershipStats.for(@unit)
      assert_equal 0, stats_after[:active_owners_count]
      assert_in_delta 0.0, stats_after[:assigned_percentage]
      assert_in_delta 100.0, stats_after[:available_percentage]
      assert_empty @unit.unit_ownerships
      assert_equal 1, @unit.unit_ownerships.with_deleted.count
      assert UnitOwnership.unscoped.exists?(id: ownership_id)
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
        name: "Concurrency Service Property #{SecureRandom.hex(4)}",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      @unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        identifier: "SRV-501",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
      @person_a = Person.create!(
        organization: @organization,
        display_name: "Concurrent Owner A",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      @person_b = Person.create!(
        organization: @organization,
        display_name: "Concurrent Owner B",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
    end

    teardown do
      ActsAsTenant.current_tenant = @organization
      # Clean up relationships to avoid FK violations
      # Tests run in transactions, so units will be cleaned up automatically
      UnitOwnership.unscoped.where(unit_id: @unit.id).delete_all if @unit
      UnitOccupancy.unscoped.where(unit_id: @unit.id).delete_all if @unit
      @person_a&.destroy
      @person_b&.destroy
      ActsAsTenant.current_tenant = nil
    end

    test "serializes concurrent creates so active assignment never exceeds 100 percent" do
      start_gate = Queue.new
      results = Queue.new

      threads = [ @person_a, @person_b ].map do |person|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ActsAsTenant.current_tenant = @organization
            start_gate.pop
            begin
              Create.call(
                unit: @unit,
                ownership_params: {
                  person_id: person.id,
                  ownership_percentage: 60,
                  starts_at: Date.current
                },
                actor: nil
              )
              results << :success
            rescue ActiveRecord::RecordInvalid
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
      assert_equal 1, @unit.unit_ownerships.count
      assert_operator @unit.unit_ownerships.sum(:ownership_percentage).to_f, :<=, 100.0
    end
  end
end
