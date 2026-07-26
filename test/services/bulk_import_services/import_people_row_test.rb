# frozen_string_literal: true

require "test_helper"

module BulkImportServices
  class ImportPeopleRowTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization
      @user = users(:one)
      @bulk_import = BulkImport.create!(
        organization: @organization,
        created_by: @user,
        import_type: BulkImport::IMPORT_TYPES[:users],
        status: "processing"
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    def build_row(payload, validation_status: BulkImportRow::VALIDATION_STATUSES[:valid])
      @bulk_import.rows.create!(
        row_number: 1,
        raw_payload: payload,
        normalized_payload: payload,
        validation_status: validation_status,
        import_status: BulkImportRow::IMPORT_STATUSES[:pending]
      )
    end

    test "creates an active natural person and an accepted organization membership" do
      row = build_row({
        "first_name" => "Ana",
        "last_name" => "Torres",
        "document_number" => "12345678",
        "phone" => "+56911112222",
        "email" => "ana.torres@example.test",
        "birthdate" => "1990-06-15"
      })

      result = ImportPeopleRow.call(row:, bulk_import: @bulk_import)

      assert_equal :imported, result
      row.reload
      assert_equal BulkImportRow::IMPORT_STATUSES[:imported], row.import_status

      person = row.target_record
      assert_instance_of Person, person
      assert_equal PersonStatuses::ACTIVE, person.status
      assert_equal PersonTypes::NATURAL, person.person_type
      assert Date.parse("1990-06-15") == person.birthdate

      membership = person.organization_membership
      assert membership.present?
      assert_equal OrganizationMembership::STATUS_ACTIVE, membership.status
      assert membership.joined_at.present?
    end

    test "skips a row already marked duplicate" do
      row = build_row(
        { "first_name" => "Ana", "last_name" => "Torres" },
        validation_status: BulkImportRow::VALIDATION_STATUSES[:duplicate]
      )
      row.update!(import_status: BulkImportRow::IMPORT_STATUSES[:pending])

      result = ImportPeopleRow.call(row:, bulk_import: @bulk_import)

      assert_equal :skipped, result
      assert_equal BulkImportRow::IMPORT_STATUSES[:skipped], row.reload.import_status
    end

    test "ready row records the ready classification" do
      row = build_row({
        "first_name" => "Ana", "last_name" => "Torres",
        "document_number" => "12345678", "email" => "ana.ready@example.test"
      })

      assert_equal :imported, ImportPeopleRow.call(row:, bulk_import: @bulk_import)
      assert_equal(
        BulkImportRow::ONBOARDING_CLASSIFICATIONS[:ready_to_create_person],
        row.reload.onboarding_classification
      )
    end

    test "existing account row is recorded as requires-incorporation without creating identity or email" do
      create_bare_user!(email: "acct@example.test")
      row = build_row({ "first_name" => "Acc", "last_name" => "Ount", "email" => "acct@example.test" })

      assert_no_enqueued_emails do
        assert_equal :skipped, ImportPeopleRow.call(row:, bulk_import: @bulk_import)
      end

      row.reload
      assert_equal BulkImportRow::IMPORT_STATUSES[:skipped], row.import_status
      assert_equal(
        BulkImportRow::ONBOARDING_CLASSIFICATIONS[:requires_incorporation],
        row.onboarding_classification
      )
      assert_nil row.target_record
    end

    test "existing person without account is recorded as requires-invitation without sending email" do
      create_person!(display_name: "No Acct", document_number: "20.202.020-2")
      row = build_row({ "first_name" => "No", "last_name" => "Acct", "document_number" => "20202020-2" })

      assert_no_enqueued_emails do
        assert_equal :skipped, ImportPeopleRow.call(row:, bulk_import: @bulk_import)
      end

      assert_equal(
        BulkImportRow::ONBOARDING_CLASSIFICATIONS[:requires_invitation],
        row.reload.onboarding_classification
      )
    end

    test "conflict row is not applied" do
      create_org_user!(email: "taken@example.test")
      create_person!(display_name: "Conflict", document_number: "40.404.040-4")
      row = build_row({
        "first_name" => "C", "last_name" => "Flict",
        "document_number" => "40404040-4", "email" => "taken@example.test"
      })

      assert_equal :skipped, ImportPeopleRow.call(row:, bulk_import: @bulk_import)
      row.reload
      assert_equal BulkImportRow::ONBOARDING_CLASSIFICATIONS[:conflict], row.onboarding_classification
      assert_nil row.target_record
    end

    test "invalid row without email and document is rejected" do
      row = build_row({ "first_name" => "No", "last_name" => "Id" })

      assert_equal :failed, ImportPeopleRow.call(row:, bulk_import: @bulk_import)
      row.reload
      assert_equal BulkImportRow::IMPORT_STATUSES[:failed], row.import_status
      assert_equal BulkImportRow::ONBOARDING_CLASSIFICATIONS[:invalid], row.onboarding_classification
    end

    test "does not assign a role or unit assignment" do
      row = build_row({
        "first_name" => "Ana",
        "last_name" => "Torres",
        "document_number" => "33334444",
        "phone" => "+56911112222",
        "email" => "no-role@example.test",
        "birthdate" => "1990-06-15"
      })

      ImportPeopleRow.call(row:, bulk_import: @bulk_import)
      person = row.reload.target_record

      assert_empty person.roles
      assert_empty person.unit_ownerships
      assert_empty person.staff_assignments
    end

    private

    def create_person!(display_name:, document_number: nil)
      person = Person.new(
        organization: @organization,
        display_name: display_name,
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      person.document_number = document_number if document_number
      person.save!
      person
    end

    def create_bare_user!(email:)
      ActsAsTenant.without_tenant do
        User.create!(email: email, password: "Password1@", password_confirmation: "Password1@",
                     name: "Bare", dni: SecureRandom.hex(4), language: Languages::ES,
                     confirmed_at: Time.current)
      end
    end

    def create_org_user!(email:)
      ActsAsTenant.with_tenant(@organization) do
        user = User.create!(email: email, password: "Password1@", password_confirmation: "Password1@",
                            name: "Org", dni: SecureRandom.hex(4), language: Languages::ES,
                            confirmed_at: Time.current)
        Accounts::ProvisionTenantIdentity.call(user: user, organization: @organization)
        user
      end
    end
  end
end
