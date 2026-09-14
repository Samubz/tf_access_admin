# frozen_string_literal: true

module People
  class FindExisting
    def self.call(**kwargs)
      new(**kwargs).call
    end

    # Looks up a Person by the blind index of the normalized email, scoped to
    # the organization (D3). Never crosses organizations.
    def self.by_email(organization:, email:)
      digest = Person.email_digest(email)
      return nil if digest.blank?

      Person.where(organization_id: organization.id).find_by(email_digest: digest)
    end

    def initialize(organization:, document_number: nil, email: nil)
      @organization = organization
      @document_number = document_number
      @email = email
    end

    def call
      find_by_document_digest || find_by_normalized_email
    end

    private

    def find_by_document_digest
      digest = Person.document_digest(@document_number)
      return nil if digest.blank?

      scoped_people.find_by(document_number_digest: digest)
    end

    def find_by_normalized_email
      normalized = normalized_email
      return nil if normalized.blank?

      find_by_user_email(normalized) || find_by_metadata_email(normalized)
    end

    def find_by_user_email(normalized)
      user = User.where("LOWER(email) = ?", normalized).first
      user&.person_for(@organization)
    end

    def find_by_metadata_email(normalized)
      scoped_people.where("metadata->>'import_email' = ?", normalized).first
    end

    def normalized_email
      @email.to_s.downcase.strip.presence
    end

    def scoped_people
      Person.where(organization_id: @organization.id)
    end
  end
end
