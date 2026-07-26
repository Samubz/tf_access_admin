# frozen_string_literal: true

module BulkImportServices
  class PeopleImportValidationContext
    include PeopleImportMode

    attr_reader :import_mode, :organization

    def initialize(bulk_import:)
      @bulk_import = bulk_import
      options = bulk_import.metadata.fetch("options", {})
      @import_mode = PeopleImportMode.resolve(options["import_mode"])
      @organization = bulk_import.organization
      @seen_document_keys = Hash.new(0)
      @seen_email_keys = Hash.new(0)
      load_existing_people_index
    end

    def register_document_key!(key)
      return if key.blank?

      @seen_document_keys[key] += 1
    end

    def document_duplicate_in_file?(key)
      return false if key.blank?

      @seen_document_keys[key] > 1
    end

    def register_email_key!(key)
      return if key.blank?

      @seen_email_keys[key] += 1
    end

    def email_duplicate_in_file?(key)
      return false if key.blank?

      @seen_email_keys[key] > 1
    end

    # Fast in-memory membership check against active people already in this
    # organization, preloaded once instead of querying per row.
    def document_taken_in_organization?(document_number)
      return false if document_number.blank?

      @existing_document_digests.include?(Person.document_digest(document_number))
    end

    def email_taken_in_organization?(email)
      normalized = email.to_s.downcase.strip
      return false if normalized.blank?

      @existing_emails.include?(normalized)
    end

    private

    def load_existing_people_index
      people = Person.where(organization_id: @organization.id, status: PersonStatuses::ACTIVE)

      @existing_document_digests = people.pluck(:document_number_digest).compact.to_set

      @existing_emails = people.joins(:user)
        .where.not(users: { email: nil })
        .pluck("users.email")
        .map { |email| email.downcase.strip }
        .to_set

      people.where("metadata ? 'import_email'").find_each do |person|
        email = person.metadata["import_email"]&.downcase&.strip
        @existing_emails << email if email.present?
      end
    end
  end
end
