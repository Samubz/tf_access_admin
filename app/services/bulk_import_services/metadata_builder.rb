# frozen_string_literal: true

module BulkImportServices
  class MetadataBuilder
    def self.call(inspection:, options: {}, column_mapper: BulkImportServices::UnitsColumnMapper)
      new(inspection:, options:, column_mapper:).call
    end

    def initialize(inspection:, options: {}, column_mapper: BulkImportServices::UnitsColumnMapper)
      @inspection = inspection
      @options = options.stringify_keys
      @column_mapper = column_mapper
    end

    def call
      column_mappings = @column_mapper.call(headers: @inspection.headers)
      selected_sheet = @inspection.selected_sheet.presence || @inspection.sheets.first

      {
        "file_inspection" => {
          "sheets" => @inspection.sheets,
          "selected_sheet" => selected_sheet,
          "headers" => @inspection.headers,
          "row_count" => @inspection.row_count,
          "error" => @inspection.error
        },
        "column_mappings" => column_mappings,
        "options" => @options
      }
    end
  end
end
