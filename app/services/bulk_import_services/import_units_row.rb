# frozen_string_literal: true

module BulkImportServices
  # Processes a validated units import row through the canonical Units::* services
  # (improve-units-foundation §7).
  class ImportUnitsRow
    include UnitsImportMode

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(row:, bulk_import:, import_context: nil)
      @row = row
      @bulk_import = bulk_import
      @import_context = import_context || ImportUnitsImportContext.new(bulk_import:)
      @payload = row.normalized_payload.deep_stringify_keys
      options = @bulk_import.metadata.fetch("options", {})
      @import_mode = UnitsImportMode.resolve(options["import_mode"])
    end

    def call
      return update_unit! if update_only?

      return skip_duplicate! if duplicate_row?
      return skip_pending! if @row.import_status == BulkImportRow::IMPORT_STATUSES[:skipped]

      unit = find_or_create_unit!
      return :failed if unit.nil?

      ActiveRecord::Base.transaction do
        import_ownership!(unit)
      end

      mark_imported!(unit)
      :imported
    rescue ActiveRecord::RecordInvalid => e
      mark_failed!(localized_record_invalid_message(e.record))
      :failed
    rescue Pundit::NotAuthorizedError
      mark_failed!(I18n.t("frontend.admin.bulk_imports.import.logs.not_authorized"))
      :failed
    rescue StandardError => e
      mark_failed!(e.message)
      :failed
    end

    def import_mode
      @import_mode
    end

    private

    def duplicate_row?
      @row.validation_status == BulkImportRow::VALIDATION_STATUSES[:duplicate]
    end

    def skip_duplicate!
      mark_skipped!(I18n.t("frontend.admin.bulk_imports.import.logs.duplicate_skipped"))
      :skipped
    end

    def skip_pending!
      mark_skipped!(I18n.t("frontend.admin.bulk_imports.import.logs.skipped"))
      :skipped
    end

    def update_unit!
      unit = resolve_unit_for_update
      if unit.nil?
        mark_failed!(I18n.t("frontend.admin.bulk_imports.validation.unit_not_found_for_update"))
        return :failed
      end

      ActiveRecord::Base.transaction do
        return :failed unless apply_descriptive_update!(unit)
        return :failed unless apply_placement_change!(unit)

        import_ownership!(unit)
      end

      mark_imported!(unit)
      :imported
    rescue ActiveRecord::RecordInvalid => e
      mark_failed!(localized_record_invalid_message(e.record))
      :failed
    rescue Pundit::NotAuthorizedError
      mark_failed!(I18n.t("frontend.admin.bulk_imports.import.logs.not_authorized"))
      :failed
    rescue StandardError => e
      mark_failed!(e.message)
      :failed
    end

    def import_ownership!(unit)
      return unless ActiveModel::Type::Boolean.new.cast(@payload["will_import_ownership"])
      return if @import_context.ignore_owners?
      return unless owner_data_present?

      person = @import_context.resolve_person!(@payload)
      if person.nil?
        raise StandardError, I18n.t("frontend.admin.bulk_imports.validation.owner_not_found")
      end

      ImportUnitOwnership.call(unit:, person:, row: @row)
    end

    def owner_data_present?
      @payload.values_at("owner_email", "owner_document").any?(&:present?)
    end

    def resolve_unit_for_update
      unit_id = @payload["target_unit_id"]
      if unit_id.present?
        return Unit.find_by(
          id: unit_id,
          organization_id: @bulk_import.organization_id,
          residential_property_id: @bulk_import.residential_property_id
        )
      end

      resolve_unit_by_identifier
    end

    def find_or_create_unit!
      resolve_unit_by_identifier || create_unit_via_service!
    end

    def create_unit_via_service!
      result = Units::Create.call(
        actor: import_actor,
        property: @bulk_import.residential_property,
        section_id: effective_section_id,
        attributes: descriptive_attributes,
        allow_initial_status: true
      )
      return result.unit if service_result_succeeded?(result)

      nil
    end

    def apply_descriptive_update!(unit)
      attrs = descriptive_attributes
      return true if attrs.empty?

      result = Units::Update.call(
        actor: import_actor,
        unit: unit,
        attributes: attrs
      )
      service_result_succeeded?(result)
    end

    def apply_placement_change!(unit)
      return true unless placement_change_requested?(unit)
      return true unless allow_placement_changes?

      result = Units::MoveToSection.call(
        actor: import_actor,
        unit: unit,
        section_id: effective_section_id
      )
      service_result_succeeded?(result)
    end

    def placement_change_requested?(unit)
      return true if ActiveModel::Type::Boolean.new.cast(@payload["placement_change_requested"])

      unit.property_section_id.to_s != effective_section_id.to_s
    end

    def descriptive_attributes
      attrs = {
        identifier: @payload["unit_identifier"],
        unit_type: @payload["unit_type"].to_s.downcase.presence,
        display_name: @payload["display_name"],
        area_m2: parse_area(@payload["area_m2"]),
        status: normalized_status
      }
      attrs.compact
    end

    def resolve_unit_by_identifier
      section_id = effective_section_id
      normalized = normalized_identifier_for(@payload["unit_identifier"])
      return nil if normalized.blank?

      Unit.find_by(
        organization_id: @bulk_import.organization_id,
        residential_property_id: @bulk_import.residential_property_id,
        property_section_id: section_id,
        normalized_identifier: normalized
      )
    end

    def normalized_identifier_for(identifier)
      Units::NormalizeIdentifier.call(identifier)&.normalized_identifier
    end

    def effective_section_id
      @bulk_import.property_section_id ||
        @bulk_import.metadata.dig("options", "property_section_id")
    end

    def import_actor
      @bulk_import.created_by
    end

    def normalized_status
      value = @payload["status"].to_s.strip.downcase.presence
      return value if value.present? && UnitStatuses::ALL.include?(value)

      nil
    end

    def parse_area(value)
      return nil if value.blank?

      BigDecimal(value.to_s)
    rescue ArgumentError
      nil
    end

    def service_result_succeeded?(result)
      return true if result.success?

      mark_failed!(result.unit.errors.full_messages.join(", "))
      false
    end

    def mark_imported!(unit)
      @row.update!(
        import_status: BulkImportRow::IMPORT_STATUSES[:imported],
        imported_at: Time.current,
        target_record: unit,
        operation: update_only? ? "update" : "create",
        failure_message: nil
      )
    end

    def mark_skipped!(message)
      @row.update!(
        import_status: BulkImportRow::IMPORT_STATUSES[:skipped],
        skipped_at: Time.current,
        failure_message: message
      )
    end

    def mark_failed!(message)
      @row.update!(
        import_status: BulkImportRow::IMPORT_STATUSES[:failed],
        failed_at: Time.current,
        failure_message: message
      )
    end

    def localized_record_invalid_message(record)
      if record.is_a?(UnitOwnership) &&
         record.errors[:ownership_percentage].any? { |message| message.include?("100%") }
        return I18n.t("frontend.admin.bulk_imports.validation.ownership_percentage_sum_exceeded")
      end

      record.errors.full_messages.join(", ")
    end
  end
end
