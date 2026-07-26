# frozen_string_literal: true

module BulkImportServices
  class UnitsImportRowValidator
    Result = Struct.new(
      :row_number,
      :raw_payload,
      :normalized_payload,
      :validation_status,
      :import_status,
      :validation_errors,
      :validation_warnings,
      :group_key,
      keyword_init: true
    )

    EMAIL_REGEX = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

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
      property_section_id = @context.property_section_id
      normalized["property_section_id"] = property_section_id

      validate_unit_identifier!(normalized)
      validate_unit_type_presence!(normalized)
      validate_unit_type!(normalized)
      validate_unit_status!(normalized)
      validate_area!(normalized)

      owner_fingerprint = owner_fingerprint_for(normalized)
      validate_owner_fields!(normalized, owner_fingerprint)
      @context.register_owner_identity!(normalized) if owner_data_present?(normalized)

      group_key = @context.build_group_key(property_section_id, normalized["unit_identifier"])
      uniqueness_key = @context.uniqueness_key(
        property_section_id,
        normalized["unit_identifier"],
        owner_fingerprint
      )

      if uniqueness_key
        @context.register_uniqueness_key!(uniqueness_key)
        validate_file_duplicate!(uniqueness_key)
      end

      validate_database_unit!(property_section_id, normalized)
      normalized["will_import_ownership"] = UnitsImportOwnershipRules.will_import_ownership?(
        context: @context,
        normalized: normalized,
        row_errors: @errors
      )
      track_group_percentage!(group_key, normalized)

      Result.new(
        row_number: @parsed_row.row_number,
        raw_payload: @parsed_row.raw_payload,
        normalized_payload: normalized,
        validation_status: final_validation_status,
        import_status: final_import_status,
        validation_errors: @errors,
        validation_warnings: @warnings,
        group_key: group_key
      )
    end

    private

    def normalize_payload(raw)
      normalized = raw.transform_keys(&:to_s).transform_values { |value| value.presence }
      normalized.delete("normalized_identifier")
      split_owner_name!(normalized)
      normalized
    end

    def split_owner_name!(normalized)
      owner_name = normalized["owner_name"]
      return if owner_name.blank?

      first_name, last_name = owner_name.split(/\s+/, 2)
      normalized["owner_first_name"] ||= first_name
      normalized["owner_last_name"] ||= last_name if last_name.present?
    end

    def validate_unit_identifier!(normalized)
      if normalized["unit_identifier"].blank?
        add_error("unit_identifier", "missing", :unit_identifier_missing)
      end
    end

    def validate_unit_type_presence!(normalized)
      return if normalized["unit_type"].present?

      add_error("unit_type", "missing", :unit_type_missing)
    end

    def validate_unit_type!(normalized)
      value = normalized["unit_type"]&.downcase
      return if value.blank?

      return if UnitTypes::ALL.include?(value)

      add_error("unit_type", "invalid", :unit_type_invalid)
    end

    def validate_unit_status!(normalized)
      value = normalized["status"]&.downcase
      return if value.blank?

      return if UnitStatuses::ALL.include?(value)

      add_error("status", "invalid", :unit_status_invalid)
    end

    def validate_area!(normalized)
      value = normalized["area_m2"]
      return if value.blank?

      Float(value)
    rescue ArgumentError, TypeError
      add_error("area_m2", "invalid", :area_invalid)
    end

    def validate_owner_fields!(normalized, _owner_fingerprint)
      owner_present = owner_data_present?(normalized)

      if owner_present && @context.ignore_owners?
        add_warning([ "owner_email", "owner_document" ].compact.join(" "), "owners_ignored", :owners_ignored)
        return
      end

      return unless @context.process_owners? && owner_present

      add_error("owner_first_name", "missing", :owner_first_name_missing) if normalized["owner_first_name"].blank?
      add_error("owner_last_name", "missing", :owner_last_name_missing) if normalized["owner_last_name"].blank?
      add_error("owner_document", "missing", :owner_document_missing) if normalized["owner_document"].blank?
      add_error("owner_email", "missing", :owner_email_missing) if normalized["owner_email"].blank?
      # add_error("ownership_percentage", "missing", :ownership_percentage_missing) if normalized["ownership_percentage"].blank?

      if normalized["owner_email"].present? && normalized["owner_email"] !~ EMAIL_REGEX
        add_error("owner_email", "invalid", :owner_email_invalid)
      end

      validate_ownership_percentage!(normalized)
      validate_owner_linking!(normalized) if @context.link_existing_owners?
    end

    def validate_owner_linking!(normalized)
      if normalized["owner_document"].blank? && normalized["owner_email"].blank?
        add_error("owner_document", "missing", :owner_identifier_missing)
        return
      end

      return if @context.owner_exists?(normalized)

      add_error("owner_document", "not_found", :owner_not_found)
    end

    def validate_ownership_percentage!(normalized)
      value = normalized["ownership_percentage"] || 100

      percentage = Float(value)
      if percentage.negative? || percentage > 100
        add_error("ownership_percentage", "invalid", :ownership_percentage_invalid)
      end
    rescue ArgumentError, TypeError
      add_error("ownership_percentage", "invalid", :ownership_percentage_invalid)
    end

    def validate_file_duplicate!(uniqueness_key)
      return unless @context.duplicate_in_file?(uniqueness_key)

      if @context.skip_duplicates?
        add_warning("unit_identifier", "duplicate_in_file", :duplicate_in_file)
      else
        add_error("unit_identifier", "duplicate_in_file", :duplicate_in_file)
      end
    end

    def validate_database_unit!(property_section_id, normalized)
      unit_identifier = normalized["unit_identifier"]
      existing_unit = if @context.update_only?
        @context.find_unit_for_update(property_section_id, unit_identifier)
      else
        @context.find_existing_unit(property_section_id, unit_identifier)
      end

      if @context.update_only?
        if @context.ambiguous_unit_for_update?(property_section_id, unit_identifier)
          add_error("unit_identifier", "unit_ambiguous_for_update", :unit_ambiguous_for_update)
          return
        end

        if existing_unit.nil?
          add_error("unit_identifier", "unit_not_found_for_update", :unit_not_found_for_update)
        else
          normalized["target_unit_id"] = existing_unit.id
          normalized["operation"] = "update"
          if placement_change_requested?(existing_unit, property_section_id)
            normalized["placement_change_requested"] = true
          end
        end
        return
      end

      return unless existing_unit

      if @context.skip_duplicates?
        add_warning("unit_identifier", "duplicate_in_database", :duplicate_in_database)
      else
        add_error("unit_identifier", "duplicate_in_database", :duplicate_in_database)
      end
    end

    def track_group_percentage!(group_key, normalized)
      return if group_key.blank?
      return unless normalized["will_import_ownership"]

      @context.add_group_percentage(
        group_key,
        UnitsImportOwnershipRules.resolved_ownership_percentage(normalized)
      )
    end

    def placement_change_requested?(unit, target_section_id)
      unit.property_section_id.to_s != target_section_id.to_s
    end

    def owner_data_present?(normalized)
      normalized.values_at("owner_email", "owner_document").any?(&:present?)
    end

    def owner_fingerprint_for(normalized)
      return "none" unless owner_data_present?(normalized)

      document = normalized["owner_document"]&.downcase&.strip
      email = normalized["owner_email"]&.downcase&.strip
      document.presence || email.presence
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
