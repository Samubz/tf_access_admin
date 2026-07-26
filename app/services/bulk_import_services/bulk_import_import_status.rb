# frozen_string_literal: true

module BulkImportServices
  class BulkImportImportStatus
    LOG_LIMIT = 20

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(bulk_import:, logs_after: nil)
      @bulk_import = bulk_import
      @logs_after = logs_after.presence
    end

    def call
      {
        status: @bulk_import.status,
        progress: progress_payload,
        logs: log_entries,
        summary: summary_payload
      }
    end

    private

    def progress_payload
      target = target_row_count
      processed = @bulk_import.imported_rows + @bulk_import.skipped_rows + @bulk_import.failed_rows
      percentage = if target.positive?
                     ((processed.to_f / target) * 100).round
      else
                     @bulk_import.progress_percentage
      end

      {
        total: target,
        processed: processed,
        created: @bulk_import.imported_rows,
        skipped: @bulk_import.skipped_rows,
        failed: @bulk_import.failed_rows,
        percentage: [ percentage, 100 ].min
      }
    end

    def target_row_count
      stored = @bulk_import.metadata.dig("import_execution", "target_rows")
      return stored.to_i if stored.present?

      import_valid_rows_only = @bulk_import.metadata.dig("import_execution", "import_valid_rows_only")
      process_service.importable_scope(
        bulk_import: @bulk_import,
        import_valid_rows_only: ActiveModel::Type::Boolean.new.cast(import_valid_rows_only != false)
      ).count
    end

    def process_service
      @bulk_import.import_type == BulkImport::IMPORT_TYPES[:users] ? ProcessPeopleImport : ProcessUnitsImport
    end

    def summary_payload
      {
        total_rows: @bulk_import.total_rows,
        valid_rows: @bulk_import.valid_rows,
        warning_rows: @bulk_import.warning_rows,
        error_rows: @bulk_import.error_rows,
        imported_rows: @bulk_import.imported_rows,
        skipped_rows: @bulk_import.skipped_rows,
        failed_rows: @bulk_import.failed_rows
      }
    end

    def log_entries
      scope = processed_rows_scope
      scope = scope.where("updated_at > ?", parsed_logs_after) if parsed_logs_after.present?

      scope.limit(LOG_LIMIT).map { |row| log_for(row) }
    end

    def processed_rows_scope
      @bulk_import.rows
        .where.not(import_status: BulkImportRow::IMPORT_STATUSES[:pending])
        .order(updated_at: :desc)
    end

    def parsed_logs_after
      return nil if @logs_after.blank?

      Time.zone.parse(@logs_after)
    rescue ArgumentError, TypeError
      nil
    end

    def log_for(row)
      {
        row_number: row.row_number,
        status: log_status_for(row),
        message: log_message_for(row),
        created_at: (row.imported_at || row.skipped_at || row.failed_at || row.updated_at)&.iso8601
      }
    end

    def log_status_for(row)
      case row.import_status
      when BulkImportRow::IMPORT_STATUSES[:imported]
        "success"
      when BulkImportRow::IMPORT_STATUSES[:skipped]
        "warning"
      else
        "error"
      end
    end

    def log_message_for(row)
      if row.import_status == BulkImportRow::IMPORT_STATUSES[:imported]
        return person_created_message(row) if @bulk_import.import_type == BulkImport::IMPORT_TYPES[:users]

        identifier = row.normalized_payload&.dig("unit_identifier").presence
        return I18n.t(
          "frontend.admin.bulk_imports.import.logs.unit_created",
          identifier: identifier || "—"
        )
      end

      row.failure_message.presence ||
        row.validation_errors.first&.dig("message") ||
        I18n.t("frontend.admin.bulk_imports.import.logs.failed")
    end

    def person_created_message(row)
      payload = row.normalized_payload || {}
      name = [ payload["first_name"], payload["last_name"] ].compact_blank.join(" ").presence
      I18n.t("frontend.admin.bulk_imports.import.logs.person_created", name: name || "—")
    end
  end
end
