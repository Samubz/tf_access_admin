# frozen_string_literal: true

module BulkImportServices
  # Lets a manager explicitly trigger the invitation/incorporation that
  # +ImportPeopleRow+ deliberately did not auto-send for classified rows
  # (bulk-import-people spec, "Manager triggers invitations after review").
  # A row is re-classified defensively right before acting on it, since real
  # state may have moved on since import (another manager already invited the
  # same person, the identity now conflicts, etc.).
  class TriggerRowInvitations
    TRIGGERABLE_CLASSIFICATIONS = [
      BulkImportRow::ONBOARDING_CLASSIFICATIONS[:requires_invitation],
      BulkImportRow::ONBOARDING_CLASSIFICATIONS[:requires_incorporation]
    ].freeze

    Result = Data.define(:counts, :results)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(bulk_import:, requested_by_person:, row_ids: nil)
      @bulk_import = bulk_import
      @requested_by_person = requested_by_person
      @row_ids = Array(row_ids).presence
    end

    def call
      counts = Hash.new(0)
      results = []

      eligible_rows.find_each do |row|
        outcome = process_row(row)
        counts[outcome[:status]] += 1
        results << outcome
      end

      Result.new(counts: counts, results: results)
    end

    private

    # Rows with a target_record are already triggered (target_record points
    # at the created OnboardingRequest, see #invite_row!) — excluding them
    # here makes a repeated "invite all pending" call naturally idempotent.
    def eligible_rows
      scope = @bulk_import.rows
        .where(onboarding_classification: TRIGGERABLE_CLASSIFICATIONS, target_record_id: nil)
        .ordered
      scope = scope.where(id: @row_ids) if @row_ids
      scope
    end

    def process_row(row)
      classification = reclassify(row).classification.to_s

      # A row still requires_invitation/incorporation, or now resolves as an
      # outright conflict, goes through InvitePerson either way — it already
      # knows how to record a conflict OnboardingRequest itself (same path the
      # manual "Invite person" admin form uses), so there's no separate branch
      # needed here for conflict.
      routable = TRIGGERABLE_CLASSIFICATIONS + [ ClassifyPeopleRow::CONFLICT.to_s ]
      return invite_row!(row, classification) if classification.in?(routable)

      skip_stale!(row, classification)
    rescue ActiveRecord::RecordNotUnique
      mark_failed!(row, I18n.t("frontend.admin.bulk_imports.import.logs.already_pending"))
      { row_id: row.id, status: :failed, classification: row.onboarding_classification }
    rescue ActiveRecord::RecordInvalid => e
      mark_failed!(row, e.record.errors.full_messages.join(", "))
      { row_id: row.id, status: :failed, classification: row.onboarding_classification }
    rescue StandardError => e
      mark_failed!(row, e.message)
      { row_id: row.id, status: :failed, classification: row.onboarding_classification }
    end

    def reclassify(row)
      payload = row.normalized_payload.deep_stringify_keys
      ClassifyPeopleRow.call(
        organization: @bulk_import.organization,
        email: payload["email"],
        document_number: payload["document_number"]
      )
    end

    # Row state moved on since import (someone else already invited them, the
    # identity now resolves as ready/duplicate/invalid): record the fresh
    # classification and stop — never call InvitePerson for a row that isn't
    # currently requires_invitation/requires_incorporation.
    def skip_stale!(row, classification)
      row.update!(
        onboarding_classification: classification,
        failure_message: I18n.t(
          "frontend.admin.bulk_imports.import.logs.reclassified_skipped",
          classification: classification
        )
      )
      { row_id: row.id, status: :skipped, classification: classification }
    end

    def invite_row!(row, classification)
      payload = row.normalized_payload.deep_stringify_keys
      result = Accounts::InvitePerson.call(
        organization: @bulk_import.organization,
        email: payload["email"],
        document_number: payload["document_number"],
        first_name: payload["first_name"],
        last_name: payload["last_name"],
        phone: payload["phone"],
        requested_by_person: @requested_by_person
      )

      return conflict_row!(row, result) if result.conflict?

      Accounts::InvitePerson.deliver(result)
      row.update!(
        target_record: result.onboarding_request,
        operation: classification == ClassifyPeopleRow::REQUIRES_INCORPORATION.to_s ? "incorporate" : "invite",
        failure_message: nil
      )
      { row_id: row.id, status: :triggered, classification: row.onboarding_classification }
    end

    def conflict_row!(row, result)
      row.update!(
        onboarding_classification: ClassifyPeopleRow::CONFLICT.to_s,
        target_record: result.onboarding_request,
        operation: "invite",
        failure_message: I18n.t("frontend.admin.bulk_imports.import.logs.conflict")
      )
      { row_id: row.id, status: :conflicted, classification: ClassifyPeopleRow::CONFLICT.to_s }
    end

    def mark_failed!(row, message)
      row.update!(failure_message: message)
    end
  end
end
