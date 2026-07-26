# frozen_string_literal: true

module BulkImportServices
  class PeopleImportRowValidator
    Result = Struct.new(
      :row_number,
      :raw_payload,
      :normalized_payload,
      :validation_status,
      :import_status,
      :validation_errors,
      :validation_warnings,
      keyword_init: true
    )

    EMAIL_REGEX = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/
    BIRTHDATE_FORMAT_REGEX = %r{\A\d{2}[-/]\d{2}[-/]\d{4}\z}

    def self.call(parsed_row:, context:)
      new(parsed_row:, context:).call
    end

    def initialize(parsed_row:, context:)
      @parsed_row = parsed_row
      @context = context
      @errors = []
      @warnings = []
    end

    def call
      normalized = normalize_payload(@parsed_row.raw_payload)

      validate_required_field!(normalized, "first_name", :first_name_missing)
      validate_required_field!(normalized, "last_name", :last_name_missing)
      validate_required_field!(normalized, "document_number", :document_number_missing)
      validate_required_field!(normalized, "phone", :phone_missing)
      validate_email!(normalized)
      validate_birthdate!(normalized)

      document_key = normalized_document_key(normalized["document_number"])
      email_key = normalized_email_key(normalized["email"])

      if document_key.present?
        @context.register_document_key!(document_key)
        validate_file_duplicate!(document_key, field: "document_number", code: "duplicate_in_file")
      end

      if email_key.present?
        @context.register_email_key!(email_key)
        validate_file_duplicate!(email_key, field: "email", code: "duplicate_in_file", email: true)
      end

      validate_organization_duplicate!(normalized, document_key, email_key)

      Result.new(
        row_number: @parsed_row.row_number,
        raw_payload: @parsed_row.raw_payload,
        normalized_payload: normalized,
        validation_status: final_validation_status,
        import_status: final_import_status,
        validation_errors: @errors,
        validation_warnings: @warnings
      )
    end

    private

    def normalize_payload(raw)
      raw.transform_keys(&:to_s).transform_values { |value| value.presence }
    end

    def validate_required_field!(normalized, field, i18n_key)
      return if normalized[field].present?

      add_error(field, "missing", i18n_key)
    end

    def validate_email!(normalized)
      value = normalized["email"]
      return if value.blank? # already reported by validate_required_field!

      add_error("email", "invalid", :email_invalid) unless value.match?(EMAIL_REGEX)
    end

    def validate_birthdate!(normalized)
      value = normalized["birthdate"]
      return if value.blank? # already reported by validate_required_field!

      unless value.match?(BIRTHDATE_FORMAT_REGEX)
        add_error("birthdate", "invalid_format", :birthdate_invalid_format)
        return
      end

      normalized_value = value.gsub("-", "/")
      date = Date.strptime(normalized_value, "%d/%m/%Y")
      if date > Date.current
        add_error("birthdate", "future", :birthdate_future)
      else
        normalized["birthdate"] = date.iso8601
      end
    rescue ArgumentError
      add_error("birthdate", "impossible", :birthdate_impossible)
    end

    def normalized_document_key(document_number)
      return nil if document_number.blank?

      Person.document_digest(document_number)
    end

    def normalized_email_key(email)
      email&.downcase&.strip.presence
    end

    def validate_file_duplicate!(key, field:, code:, email: false)
      duplicate = email ? @context.email_duplicate_in_file?(key) : @context.document_duplicate_in_file?(key)
      return unless duplicate

      if @context.skip_duplicates?
        add_warning(field, code, :"#{field}_#{code}")
      else
        add_error(field, code, :"#{field}_#{code}")
      end
    end

    def validate_organization_duplicate!(normalized, document_key, email_key)
      document_taken = document_key.present? && @context.document_taken_in_organization?(normalized["document_number"])
      email_taken = email_key.present? && @context.email_taken_in_organization?(normalized["email"])
      return unless document_taken || email_taken

      field = document_taken ? "document_number" : "email"

      if @context.skip_duplicates?
        add_warning(field, "duplicate_in_organization", :"#{field}_duplicate_in_organization")
      else
        add_error(field, "duplicate_in_organization", :"#{field}_duplicate_in_organization")
      end
    end

    def final_validation_status
      return BulkImportRow::VALIDATION_STATUSES[:error] if @errors.any?

      if @warnings.any? { |warning| warning["code"].to_s.start_with?("duplicate") }
        return BulkImportRow::VALIDATION_STATUSES[:duplicate]
      end

      return BulkImportRow::VALIDATION_STATUSES[:warning] if @warnings.any?

      BulkImportRow::VALIDATION_STATUSES[:valid]
    end

    def final_import_status
      if final_validation_status == BulkImportRow::VALIDATION_STATUSES[:error]
        return BulkImportRow::IMPORT_STATUSES[:pending]
      end

      if final_validation_status == BulkImportRow::VALIDATION_STATUSES[:duplicate]
        return BulkImportRow::IMPORT_STATUSES[:skipped] if @context.skip_duplicates?

        return BulkImportRow::IMPORT_STATUSES[:pending]
      end

      BulkImportRow::IMPORT_STATUSES[:pending]
    end

    def add_error(field, code, i18n_key)
      @errors << issue(field, code, i18n_key)
    end

    def add_warning(field, code, i18n_key)
      @warnings << issue(field, code, i18n_key)
    end

    def issue(field, code, i18n_key)
      {
        "field" => field,
        "code" => code,
        "message" => I18n.t("frontend.admin.bulk_imports.validation.#{i18n_key}")
      }
    end
  end
end
