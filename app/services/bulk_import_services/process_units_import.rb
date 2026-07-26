# frozen_string_literal: true

module BulkImportServices
  class ProcessUnitsImport
    # Filas con error de validación nunca se importan; el flag solo amplía el conjunto
    # entre "válidas + advertencias" y "válidas + advertencias + duplicadas".
    STRICT_IMPORTABLE_VALIDATION_STATUSES = [
      BulkImportRow::VALIDATION_STATUSES[:valid],
      BulkImportRow::VALIDATION_STATUSES[:warning]
    ].freeze

    RELAXED_IMPORTABLE_VALIDATION_STATUSES = (
      STRICT_IMPORTABLE_VALIDATION_STATUSES +
      [ BulkImportRow::VALIDATION_STATUSES[:duplicate] ]
    ).freeze

    COUNTER_REFRESH_BATCH_SIZE = 25

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def self.importable_scope(bulk_import:, import_valid_rows_only:)
      validation_statuses = if import_valid_rows_only
                              STRICT_IMPORTABLE_VALIDATION_STATUSES
      else
                              RELAXED_IMPORTABLE_VALIDATION_STATUSES
      end

      bulk_import.rows
        .pending_import
        .where(validation_status: validation_statuses)
        .ordered
    end

    def initialize(bulk_import:)
      @bulk_import = bulk_import
      @import_valid_rows_only = import_valid_rows_only?
      @rows_processed_since_refresh = 0
    end

    # Importación parcial: un fallo por fila no detiene el lote; el estado final
    # refleja filas importadas, omitidas y fallidas (completed_with_errors).
    def call
      return unless @bulk_import.processing?

      rows = self.class.importable_scope(
        bulk_import: @bulk_import,
        import_valid_rows_only: @import_valid_rows_only
      )

      import_context = ImportUnitsImportContext.new(bulk_import: @bulk_import)

      rows.find_each do |row|
        ImportUnitsRow.call(row:, bulk_import: @bulk_import, import_context:)
        @rows_processed_since_refresh += 1
        refresh_counters_if_needed!
      end

      finish_import!
      @bulk_import
    rescue StandardError => e
      refresh_counters!
      @bulk_import.update!(
        failure_message: e.message,
        finished_at: Time.current
      )
      @bulk_import.fail_import! if @bulk_import.may_fail_import?
      raise
    end

    private

    def import_valid_rows_only?
      value = @bulk_import.metadata.dig("import_execution", "import_valid_rows_only")
      ActiveModel::Type::Boolean.new.cast(value != false)
    end

    def refresh_counters_if_needed!
      return unless @rows_processed_since_refresh >= COUNTER_REFRESH_BATCH_SIZE

      refresh_counters!
      @rows_processed_since_refresh = 0
    end

    def refresh_counters!
      rows = @bulk_import.rows
      @bulk_import.update!(
        imported_rows: rows.imported.count,
        skipped_rows: rows.where(import_status: BulkImportRow::IMPORT_STATUSES[:skipped]).count,
        failed_rows: rows.failed_import.count
      )
    end

    def finish_import!
      refresh_counters!

      if @bulk_import.failed_rows.positive?
        @bulk_import.complete_with_errors! if @bulk_import.may_complete_with_errors?
      elsif @bulk_import.may_complete?
        @bulk_import.complete!
      end

      @bulk_import.update!(finished_at: Time.current)
    end
  end
end
