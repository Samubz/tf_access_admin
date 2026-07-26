# frozen_string_literal: true

module BulkImportServices
  class ListBulkImportRows
    PREVIEW_PER_PAGE = 10
    MAX_PER_PAGE = 100
    FILTERS = %w[all valid warnings errors].freeze

    Result = Struct.new(:rows, :pagination, :summary, keyword_init: true)

    def self.call(bulk_import:, page: 1, per_page: PREVIEW_PER_PAGE, filter: "all", search: nil)
      new(bulk_import:, page:, per_page:, filter:, search:).call
    end

    def initialize(bulk_import:, page:, per_page:, filter:, search:)
      @bulk_import = bulk_import
      @page = [ page.to_i, 1 ].max
      @per_page = if per_page.present?
                    per_page.to_i.clamp(1, MAX_PER_PAGE)
      else
                    PREVIEW_PER_PAGE
      end
      @filter = FILTERS.include?(filter.to_s) ? filter.to_s : "all"
      @search = search.to_s.strip
    end

    def call
      scope = @bulk_import.rows.ordered
      scope = apply_filter(scope)
      scope = apply_search(scope)

      paginated = scope.page(@page).per(@per_page)

      Result.new(
        rows: paginated,
        pagination: pagination_for(paginated),
        summary: summary_for(@bulk_import)
      )
    end

    private

    def apply_filter(scope)
      case @filter
      when "valid"
        scope.where(validation_status: BulkImportRow::VALIDATION_STATUSES[:valid])
      when "warnings"
        scope.where(
          validation_status: [
            BulkImportRow::VALIDATION_STATUSES[:warning],
            BulkImportRow::VALIDATION_STATUSES[:duplicate]
          ]
        )
      when "errors"
        scope.where(validation_status: BulkImportRow::VALIDATION_STATUSES[:error])
      else
        scope
      end
    end

    def apply_search(scope)
      return scope if @search.blank?

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@search)}%"
      scope.where(search_sql, pattern: pattern)
    end

    def search_sql
      if @bulk_import.import_type == BulkImport::IMPORT_TYPES[:users]
        <<~SQL.squish
          row_number::text ILIKE :pattern
          OR normalized_payload->>'first_name' ILIKE :pattern
          OR normalized_payload->>'last_name' ILIKE :pattern
          OR normalized_payload->>'document_number' ILIKE :pattern
          OR normalized_payload->>'email' ILIKE :pattern
          OR normalized_payload->>'phone' ILIKE :pattern
        SQL
      else
        <<~SQL.squish
          row_number::text ILIKE :pattern
          OR normalized_payload->>'unit_identifier' ILIKE :pattern
          OR normalized_payload->>'owner_document' ILIKE :pattern
        SQL
      end
    end

    def pagination_for(collection)
      {
        current_page: collection.current_page,
        per_page: @per_page,
        total_pages: collection.total_pages,
        total_count: collection.total_count
      }
    end

    def summary_for(bulk_import)
      {
        total_rows: bulk_import.total_rows,
        valid_rows: bulk_import.valid_rows,
        warning_rows: bulk_import.warning_rows,
        error_rows: bulk_import.error_rows,
        skipped_rows: bulk_import.skipped_rows,
        duplicate_rows: bulk_import.rows.where(
          validation_status: BulkImportRow::VALIDATION_STATUSES[:duplicate]
        ).count,
        pending_invitation_rows: bulk_import.rows.where(
          onboarding_classification: BulkImportRow::ONBOARDING_CLASSIFICATIONS[:requires_invitation],
          target_record_id: nil
        ).count,
        pending_incorporation_rows: bulk_import.rows.where(
          onboarding_classification: BulkImportRow::ONBOARDING_CLASSIFICATIONS[:requires_incorporation],
          target_record_id: nil
        ).count
      }
    end
  end
end
