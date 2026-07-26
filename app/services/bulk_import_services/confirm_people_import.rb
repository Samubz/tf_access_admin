# frozen_string_literal: true

module BulkImportServices
  class ConfirmPeopleImport
    CONFIRMABLE_STATUSES = %w[validated].freeze
    IN_PROGRESS_STATUSES = %w[confirmed processing].freeze

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(bulk_import:, import_valid_rows_only: true)
      @bulk_import = bulk_import
      @import_valid_rows_only = ActiveModel::Type::Boolean.new.cast(import_valid_rows_only)
    end

    def call
      return @bulk_import if in_progress_import?

      ensure_confirmable!

      target_rows = importable_rows.count
      metadata = @bulk_import.metadata.deep_dup
      metadata["import_execution"] = {
        "import_valid_rows_only" => @import_valid_rows_only,
        "target_rows" => target_rows,
        "confirmed_at" => Time.current.iso8601
      }

      @bulk_import.update!(
        metadata: metadata,
        confirmed_at: Time.current
      )
      @bulk_import.confirm! if @bulk_import.may_confirm?
      @bulk_import.start_processing! if @bulk_import.may_start_processing?
      @bulk_import.update!(processing_started_at: Time.current) if @bulk_import.processing?

      ProcessPeopleImportJob.perform_later(@bulk_import.id)

      @bulk_import
    end

    private

    def in_progress_import?
      IN_PROGRESS_STATUSES.include?(@bulk_import.status)
    end

    def ensure_confirmable!
      return if CONFIRMABLE_STATUSES.include?(@bulk_import.status)

      @bulk_import.errors.add(:status, :invalid)
      raise ActiveRecord::RecordInvalid, @bulk_import
    end

    def importable_rows
      ProcessPeopleImport.importable_scope(
        bulk_import: @bulk_import,
        import_valid_rows_only: @import_valid_rows_only
      )
    end
  end
end
