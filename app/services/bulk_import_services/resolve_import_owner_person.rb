# frozen_string_literal: true

module BulkImportServices
  class ResolveImportOwnerPerson
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def self.find_existing(organization:, normalized:)
      new(context: nil, organization:, normalized:).find_existing_person
    end

    def initialize(context: nil, normalized:, organization: nil)
      @context = context
      @normalized = normalized.deep_stringify_keys
      @organization = organization || context&.bulk_import&.organization
    end

    def call
      person = find_existing_person
      return person if person
      return nil unless @context&.create_missing_owners?

      create_person!
    end

    def find_existing_person
      People::FindExisting.call(
        organization: @organization,
        document_number: @normalized["owner_document"],
        email: owner_email
      )
    end

    private

    def create_person!
      person = Person.new(
        organization: @organization,
        first_name: @normalized["owner_first_name"],
        last_name: @normalized["owner_last_name"],
        display_name: display_name,
        person_type: PersonTypes::NATURAL,
        status: "active",
        # document_number_digest: document_digest,
        document_type: "national_id",
        # metadata: owner_metadata
      )

      person.document_number = @normalized["owner_document"]
      person.contact_email = owner_email
      person.save!

      person.add_role(AvailableRoles::CLIENT) unless person.has_role?(AvailableRoles::CLIENT)
      person
    end

    def display_name
      parts = [ @normalized["owner_first_name"], @normalized["owner_last_name"] ].compact_blank
      parts.join(" ").presence || @normalized["owner_document"].presence || owner_email || "—"
    end

    def owner_metadata
      email = owner_email
      return {} if email.blank?

      { "import_email" => email }
    end

    def owner_email
      @normalized["owner_email"]&.downcase&.strip.presence
    end
  end
end
