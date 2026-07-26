# frozen_string_literal: true

module BulkImportServices
  class UnitsSpreadsheetReader
    ParsedRow = Struct.new(:row_number, :raw_payload, keyword_init: true)

    def self.call(bulk_import:)
      new(bulk_import:).call
    end

    def initialize(bulk_import:)
      @bulk_import = bulk_import
    end

    def call
      raise ActiveStorage::FileNotFoundError unless @bulk_import.file.attached?

      inspection = @bulk_import.metadata.fetch("file_inspection", {})
      selected_sheet = inspection["selected_sheet"]
      column_mappings = @bulk_import.metadata.fetch("column_mappings", [])
      header_index = build_header_index(column_mappings)

      rows = []

      @bulk_import.file.blob.open do |tempfile|
        spreadsheet = Roo::Spreadsheet.open(
          tempfile.path,
          extension: extension_for_blob
        )
        sheet = spreadsheet.sheet(selected_sheet)
        next rows if sheet.last_row.to_i < 2

        (2..sheet.last_row).each do |row_number|
          raw_payload = extract_row_payload(sheet, row_number, header_index)
          next if raw_payload.values.all?(&:blank?)

          rows << ParsedRow.new(row_number:, raw_payload:)
        end
      end

      rows
    end

    private

    def build_header_index(column_mappings)
      column_mappings.each_with_object({}) do |mapping, index|
        source = mapping["source"]
        target = mapping["target"]
        next if source.blank? || target.blank?

        index[target] = source
      end
    end

    def extract_row_payload(sheet, row_number, header_index)
      header_index.each_with_object({}) do |(target, source_header), payload|
        column_number = source_header_column(sheet, source_header)
        next unless column_number

        value = sheet.cell(row_number, column_number)
        if value.present?
          # Convert Date/Time objects to DD/MM/YYYY format for birthdate
          if (value.is_a?(Date) || value.is_a?(Time)) && target == "birthdate"
            payload[target] = value.strftime("%d/%m/%Y")
          else
            payload[target] = value.to_s.strip
          end
        else
          payload[target] = nil
        end
      end
    end

    def source_header_column(sheet, header)
      @header_columns ||= {}
      return @header_columns[header] if @header_columns.key?(header)

      first_row = sheet.row(1).map { |cell| cell.to_s.strip }
      @header_columns[header] = first_row.index(header)&.then { |index| index + 1 }
    end

    def extension_for_blob
      BulkImportServices::FileInspector::EXTENSION_BY_CONTENT_TYPE[@bulk_import.content_type] ||
        File.extname(@bulk_import.original_filename.to_s).delete_prefix(".").downcase.to_sym
    end
  end
end
