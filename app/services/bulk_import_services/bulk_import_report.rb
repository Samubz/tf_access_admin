# frozen_string_literal: true

require "csv"

module BulkImportServices
  class BulkImportReport
    UNIT_HEADERS = %w[
      row_number
      validation_status
      import_status
      unit_identifier
      property_section_id
      owner_document
      owner_email
      message
    ].freeze

    PEOPLE_HEADERS = %w[
      row_number
      validation_status
      import_status
      first_name
      last_name
      document_number
      email
      phone
      message
    ].freeze

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(bulk_import:)
      @bulk_import = bulk_import
    end

    def call
      "\uFEFF#{csv_body}"
    end

    private

    def people_import?
      @bulk_import.import_type == BulkImport::IMPORT_TYPES[:users]
    end

    def headers
      people_import? ? PEOPLE_HEADERS : UNIT_HEADERS
    end

    def csv_body
      CSV.generate(headers: true) do |csv|
        csv << headers
        @bulk_import.rows.ordered.find_each do |row|
          csv << report_row(row)
        end
      end
    end

    def report_row(row)
      return people_report_row(row) if people_import?

      [
        row.row_number,
        row.validation_status,
        row.import_status,
        payload_value(row, "unit_identifier"),
        payload_value(row, "property_section_id"),
        payload_value(row, "owner_document"),
        payload_value(row, "owner_email"),
        report_message_for(row)
      ]
    end

    def people_report_row(row)
      [
        row.row_number,
        row.validation_status,
        row.import_status,
        payload_value(row, "first_name"),
        payload_value(row, "last_name"),
        payload_value(row, "document_number"),
        payload_value(row, "email"),
        payload_value(row, "phone"),
        report_message_for(row)
      ]
    end

    def payload_value(row, key)
      row.normalized_payload&.dig(key.to_s)
    end

    def report_message_for(row)
      return row.failure_message if row.failure_message.present?

      issue_messages(row.validation_errors).presence ||
        issue_messages(row.validation_warnings)
    end

    def issue_messages(issues)
      return nil if issues.blank?

      Array(issues).filter_map do |issue|
        next unless issue.is_a?(Hash)

        issue["message"].presence
      end.join("; ").presence
    end
  end
end
