# frozen_string_literal: true

module BulkImportServices
  class UnitsImportValidationContext
    include OwnerImportMode
    include UnitsImportMode

    attr_reader :import_mode, :owner_import_mode, :property_section_id, :residential_property

    def initialize(bulk_import:)
      @bulk_import = bulk_import
      options = bulk_import.metadata.fetch("options", {})
      @import_mode = UnitsImportMode.resolve(options["import_mode"])
      @owner_import_mode = OwnerImportMode.resolve(options["owner_import_mode"])
      @property_section_id = resolve_property_section_id_option(options)
      @residential_property = bulk_import.residential_property
      @existing_units = load_existing_units
      @seen_uniqueness_keys = Hash.new(0)
      @group_percentages = Hash.new(0.0)
      @owner_document_emails = Hash.new { |hash, key| hash[key] = Set.new }
      @owner_email_documents = Hash.new { |hash, key| hash[key] = Set.new }
      load_owner_lookup_index
      load_existing_group_percentages
    end

    def owner_exists?(normalized)
      document = normalized["owner_document"]&.downcase&.strip
      if document.present?
        digest = self.class.document_digest(document)
        return true if @owner_document_digests.include?(digest)
      end

      email = normalized["owner_email"]&.downcase&.strip
      return true if email.present? && @owner_emails.include?(email)

      # name = normalized["owner_name"]&.downcase&.strip
      # return true if name.present? && @owner_names.include?(normalize_owner_key(name))

      false
    end

    def self.document_digest(document_number)
      normalized = document_number.to_s.downcase.gsub(/[^a-z0-9]/, "")
      Digest::SHA256.hexdigest(normalized)
    end

    def existing_unit?(property_section_id, unit_identifier)
      find_existing_unit(property_section_id, unit_identifier).present?
    end

    def find_existing_unit(property_section_id, unit_identifier)
      return nil if unit_identifier.blank?

      normalized = normalize_identifier(unit_identifier)
      context = normalize_section_context(property_section_id)
      @existing_units[[ context, normalized ]]
    end

    def find_unit_for_update(property_section_id, unit_identifier)
      normalized = normalize_identifier(unit_identifier)
      return nil if normalized.blank?

      context = normalize_section_context(property_section_id)
      in_section = @existing_units[[ context, normalized ]]
      return in_section if in_section.present?

      return nil unless update_only?

      matches = @residential_property.units.where(normalized_identifier: normalized).to_a
      return matches.first if matches.one?

      nil
    end

    def ambiguous_unit_for_update?(property_section_id, unit_identifier)
      return false unless update_only?

      normalized = normalize_identifier(unit_identifier)
      return false if normalized.blank?

      context = normalize_section_context(property_section_id)
      return false if @existing_units[[ context, normalized ]].present?

      @residential_property.units.where(normalized_identifier: normalized).count > 1
    end

    def register_uniqueness_key!(key)
      @seen_uniqueness_keys[key] += 1
    end

    def duplicate_in_file?(key)
      @seen_uniqueness_keys[key] > 1
    end

    def add_group_percentage(group_key, percentage)
      return if group_key.blank? || percentage.nil?

      @group_percentages[group_key] += percentage.to_f
    end

    def group_percentage_exceeded?(group_key)
      (@group_percentages[group_key] || 0) > 100.0
    end

    def uniqueness_key(property_section_id, unit_identifier, owner_fingerprint)
      group_key = build_group_key(property_section_id, unit_identifier)
      return nil if group_key.nil?

      "#{group_key}:#{owner_fingerprint}"
    end

    def build_group_key(property_section_id, unit_identifier)
      return nil if unit_identifier.blank?

      context = normalize_section_context(property_section_id)
      "unit:#{context}:#{normalize_identifier(unit_identifier)}"
    end

    def register_owner_identity!(normalized)
      return unless process_owners?
      return unless owner_data_present?(normalized)

      document = normalized["owner_document"]&.downcase&.strip
      email = normalized["owner_email"]&.downcase&.strip

      if document.present?
        digest = self.class.document_digest(document)
        @owner_document_emails[digest] << email if email.present?
      end

      return if email.blank?

      digest_key = document.present? ? self.class.document_digest(document) : :__no_document__
      @owner_email_documents[email] << digest_key
    end

    def apply_owner_identity_conflicts!(results)
      return unless process_owners?

      conflict_digests = @owner_document_emails.select { |_digest, emails| emails.size > 1 }.keys
      conflict_emails = @owner_email_documents.select { |_email, digests| digests.size > 1 }.keys

      results.each do |result|
        apply_document_email_conflict!(result, conflict_digests)
        apply_email_document_conflict!(result, conflict_emails)
      end
    end

    def owner_data_present?(normalized)
      normalized.values_at("owner_email", "owner_document").any?(&:present?)
    end

    private

    def apply_document_email_conflict!(result, conflict_digests)
      document = result.normalized_payload["owner_document"]&.downcase&.strip
      return if document.blank?

      digest = self.class.document_digest(document)
      return unless conflict_digests.include?(digest)

      result.validation_errors << identity_issue(
        "owner_document",
        "owner_document_email_conflict",
        :owner_document_email_conflict
      )
      mark_result_errored!(result)
    end

    def apply_email_document_conflict!(result, conflict_emails)
      email = result.normalized_payload["owner_email"]&.downcase&.strip
      return if email.blank?
      return unless conflict_emails.include?(email)

      result.validation_errors << identity_issue(
        "owner_email",
        "owner_email_document_conflict",
        :owner_email_document_conflict
      )
      mark_result_errored!(result)
    end

    def identity_issue(field, code, i18n_key)
      {
        "field" => field,
        "code" => code,
        "message" => I18n.t("frontend.admin.bulk_imports.validation.#{i18n_key}")
      }
    end

    def mark_result_errored!(result)
      result.validation_status = BulkImportRow::VALIDATION_STATUSES[:error]
      result.import_status = BulkImportRow::IMPORT_STATUSES[:pending]
    end

    def mark_result_warned!(result)
      return if result.validation_status == BulkImportRow::VALIDATION_STATUSES[:error]

      if result.validation_warnings.any? { |warning| warning["code"].to_s.start_with?("duplicate") }
        result.validation_status = BulkImportRow::VALIDATION_STATUSES[:duplicate]
      else
        result.validation_status = BulkImportRow::VALIDATION_STATUSES[:warning]
      end
    end

    def resolve_property_section_id_option(options)
      options["property_section_id"].presence ||
        @bulk_import.property_section_id
    end

    def load_owner_lookup_index
      people = Person.where(organization_id: @bulk_import.organization_id)

      @owner_document_digests = people.pluck(:document_number_digest).compact.to_set
      @owner_names = people.pluck(:display_name).filter_map { |name| normalize_owner_key(name) }.to_set
      @owner_emails = people.joins(:user)
        .where.not(users: { email: nil })
        .pluck("users.email")
        .map { |email| email.downcase.strip }
        .to_set

      people.where("metadata ? 'import_email'").find_each do |person|
        email = person.metadata["import_email"]&.downcase&.strip
        @owner_emails << email if email.present?
      end
    end

    def normalize_owner_key(value)
      value.to_s.downcase.gsub(/\s+/, " ").strip.presence
    end

    def load_existing_units
      Unit.where(residential_property_id: @residential_property.id)
        .index_by { |unit| [ normalize_section_context(unit.property_section_id), unit.normalized_identifier ] }
    end

    def load_existing_group_percentages
      return unless update_only?

      UnitOwnership
        .joins(:person, :unit)
        .where(
          organization_id: @bulk_import.organization_id,
          status: UnitOwnership::STATUS_ACTIVE,
          units: { residential_property_id: @residential_property.id },
          people: { status: PersonStatuses::ACTIVE, deleted_at: nil }
        )
        .includes(:unit)
        .find_each do |ownership|
          key = build_group_key(ownership.unit.property_section_id, ownership.unit.identifier)
          next if key.blank?

          @group_percentages[key] += ownership.ownership_percentage.to_f
        end
    end

    def normalize_identifier(identifier)
      Units::NormalizeIdentifier.call(identifier)&.normalized_identifier
    end

    def normalize_section_context(property_section_id)
      property_section_id.present? ? property_section_id : :root
    end
  end
end
