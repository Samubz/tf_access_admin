# frozen_string_literal: true

require "test_helper"

module BulkImportServices
  class TriggerRowInvitationsTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization
      @user = users(:one)
      @requested_by = @user.person_for(@organization)
      @bulk_import = BulkImport.create!(
        organization: @organization,
        created_by: @user,
        import_type: BulkImport::IMPORT_TYPES[:users],
        status: "completed"
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    def build_row(payload, classification:, row_number: 1)
      @bulk_import.rows.create!(
        row_number: row_number,
        raw_payload: payload,
        normalized_payload: payload,
        validation_status: BulkImportRow::VALIDATION_STATUSES[:valid],
        import_status: BulkImportRow::IMPORT_STATUSES[:skipped],
        onboarding_classification: classification
      )
    end

    test "triggers an invitation for a requires_invitation row" do
      create_person!(display_name: "Ana Torres", document_number: "10.101.010-1")
      row = build_row(
        { "first_name" => "Ana", "last_name" => "Torres", "document_number" => "10101010-1" },
        classification: BulkImportRow::ONBOARDING_CLASSIFICATIONS[:requires_invitation]
      )

      result = nil
      assert_enqueued_emails 1 do
        result = TriggerRowInvitations.call(bulk_import: @bulk_import, requested_by_person: @requested_by)
      end

      assert_equal({ triggered: 1 }, result.counts)
      row.reload
      assert_equal "OnboardingRequest", row.target_record_type
      assert_equal OnboardingRequest::STATUS_PENDING, row.target_record.status
      assert_equal "invite", row.operation
      assert_nil row.failure_message
    end

    test "triggers an incorporation for a requires_incorporation row" do
      create_bare_user!(email: "acct.trigger@example.test")
      row = build_row(
        { "first_name" => "Acc", "last_name" => "Ount", "email" => "acct.trigger@example.test" },
        classification: BulkImportRow::ONBOARDING_CLASSIFICATIONS[:requires_incorporation]
      )

      result = nil
      assert_enqueued_emails 1 do
        result = TriggerRowInvitations.call(bulk_import: @bulk_import, requested_by_person: @requested_by)
      end

      assert_equal({ triggered: 1 }, result.counts)
      row.reload
      assert_equal "OnboardingRequest", row.target_record_type
      assert_equal "incorporate", row.operation
    end

    test "an already-triggered row is not re-selected on a second call" do
      create_person!(display_name: "Idem Potent", document_number: "11.101.010-1")
      row = build_row(
        { "first_name" => "Idem", "last_name" => "Potent", "document_number" => "11101010-1" },
        classification: BulkImportRow::ONBOARDING_CLASSIFICATIONS[:requires_invitation]
      )

      assert_enqueued_emails 1 do
        TriggerRowInvitations.call(bulk_import: @bulk_import, requested_by_person: @requested_by)
      end

      result = nil
      assert_no_enqueued_emails do
        result = TriggerRowInvitations.call(bulk_import: @bulk_import, requested_by_person: @requested_by)
      end

      assert_equal({}, result.counts)
      assert_equal 1, OnboardingRequest.where(person: row.reload.target_record.person).count
    end

    test "reclassifies to conflict and does not send an email" do
      create_org_user!(email: "conflict.trigger@example.test")
      create_person!(display_name: "Conflict Row", document_number: "70.707.070-7")
      row = build_row(
        {
          "first_name" => "C", "last_name" => "Row",
          "email" => "conflict.trigger@example.test", "document_number" => "70707070-7"
        },
        classification: BulkImportRow::ONBOARDING_CLASSIFICATIONS[:requires_invitation]
      )

      result = nil
      assert_no_enqueued_emails do
        result = TriggerRowInvitations.call(bulk_import: @bulk_import, requested_by_person: @requested_by)
      end

      assert_equal({ conflicted: 1 }, result.counts)
      row.reload
      assert_equal BulkImportRow::ONBOARDING_CLASSIFICATIONS[:conflict], row.onboarding_classification
      assert_equal "OnboardingRequest", row.target_record_type
      assert_equal OnboardingRequest::STATUS_CONFLICT, row.target_record.status
    end

    test "reclassifies to duplicate when a pending request already exists and skips" do
      person = create_person!(display_name: "Already Pending", document_number: "80.808.080-8")
      OnboardingRequest.create!(
        organization: @organization, person: person,
        requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP,
        status: OnboardingRequest::STATUS_PENDING, expires_at: 7.days.from_now
      )
      row = build_row(
        { "first_name" => "Already", "last_name" => "Pending", "document_number" => "80808080-8" },
        classification: BulkImportRow::ONBOARDING_CLASSIFICATIONS[:requires_invitation]
      )

      result = nil
      assert_no_enqueued_emails do
        result = TriggerRowInvitations.call(bulk_import: @bulk_import, requested_by_person: @requested_by)
      end

      assert_equal({ skipped: 1 }, result.counts)
      row.reload
      assert_equal BulkImportRow::ONBOARDING_CLASSIFICATIONS[:duplicate], row.onboarding_classification
      assert_nil row.target_record
    end

    test "a per-row failure does not abort the batch" do
      create_person!(display_name: "First Row", document_number: "12.101.010-1")
      create_person!(display_name: "Second Row", document_number: "13.101.010-1")
      row1 = build_row(
        { "first_name" => "First", "last_name" => "Row", "document_number" => "12101010-1" },
        classification: BulkImportRow::ONBOARDING_CLASSIFICATIONS[:requires_invitation], row_number: 1
      )
      row2 = build_row(
        { "first_name" => "Second", "last_name" => "Row", "document_number" => "13101010-1" },
        classification: BulkImportRow::ONBOARDING_CLASSIFICATIONS[:requires_invitation], row_number: 2
      )

      # BulkImportRow#find_each does not honor the .ordered scope (it forces
      # its own primary-key batch order), so which row is processed first is
      # not guaranteed — only fail the *first* row this stub sees.
      seen_documents = []
      original_call = Accounts::InvitePerson.method(:call)
      Accounts::InvitePerson.define_singleton_method(:call) do |**kwargs|
        seen_documents << kwargs[:document_number]
        raise ActiveRecord::RecordNotUnique, "boom" if seen_documents.size == 1

        original_call.call(**kwargs)
      end

      begin
        result = TriggerRowInvitations.call(bulk_import: @bulk_import, requested_by_person: @requested_by)
      ensure
        Accounts::InvitePerson.define_singleton_method(:call, &original_call)
      end

      assert_equal [ "12101010-1", "13101010-1" ], seen_documents.sort
      assert_equal({ failed: 1, triggered: 1 }, result.counts)

      failed_row, triggered_row = [ row1.reload, row2.reload ].partition { |r| r.failure_message.present? }.map(&:first)
      assert_equal "Another invitation is already in flight for this person", failed_row.failure_message
      assert_equal "OnboardingRequest", triggered_row.target_record_type
    end

    test "row_ids scopes the batch to the given rows" do
      create_person!(display_name: "One Row", document_number: "14.101.010-1")
      create_person!(display_name: "Two Row", document_number: "15.101.010-1")
      row1 = build_row(
        { "first_name" => "One", "last_name" => "Row", "document_number" => "14101010-1" },
        classification: BulkImportRow::ONBOARDING_CLASSIFICATIONS[:requires_invitation], row_number: 1
      )
      row2 = build_row(
        { "first_name" => "Two", "last_name" => "Row", "document_number" => "15101010-1" },
        classification: BulkImportRow::ONBOARDING_CLASSIFICATIONS[:requires_invitation], row_number: 2
      )

      result = nil
      assert_enqueued_emails 1 do
        result = TriggerRowInvitations.call(
          bulk_import: @bulk_import, requested_by_person: @requested_by, row_ids: [ row1.id ]
        )
      end

      assert_equal({ triggered: 1 }, result.counts)
      assert row1.reload.target_record.present?
      assert_nil row2.reload.target_record
    end

    private

    def create_person!(display_name:, document_number: nil)
      person = Person.new(
        organization: @organization, display_name: display_name,
        person_type: PersonTypes::NATURAL, status: PersonStatuses::ACTIVE
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
