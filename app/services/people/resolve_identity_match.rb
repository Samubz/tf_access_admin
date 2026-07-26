# frozen_string_literal: true

module People
  # Resolves how an incoming person (email + optional document) maps to existing
  # identities within an organization, per the identity-resolution spec:
  #
  # - Email is the transversal account key: it resolves an existing +User+
  #   automatically (confirmed or not).
  # - Document is the per-organization person key.
  # - Weak signals (name, phone) never establish identity and are not inputs here.
  # - Conflicting identifiers are reported without changing any association.
  #
  # Returns a +Result+; it never creates or mutates records. This is an additive
  # service — +People::FindExisting+ and its callers are untouched. Finer conflict
  # cases and the resolution flow live in +IdentityConflicts::Resolve+ (tasks §12).
  class ResolveIdentityMatch
    STATUS_NONE     = :none
    STATUS_PERSON   = :matched_person
    STATUS_ACCOUNT  = :matched_account
    STATUS_CONFLICT = :conflict

    Result = Data.define(:status, :person, :user, :conflict_reason) do
      def none?     = status == STATUS_NONE
      def person?   = status == STATUS_PERSON
      def account?  = status == STATUS_ACCOUNT
      def conflict? = status == STATUS_CONFLICT
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(organization:, email: nil, document_number: nil)
      @organization = organization
      @email = email
      @document_number = document_number
    end

    def call
      person_by_document = find_person_by_document
      user_by_email = find_user_by_email
      person_of_user = user_by_email&.person_for(@organization)

      return resolve_with_document(person_by_document, user_by_email, person_of_user) if person_by_document

      resolve_without_document(user_by_email, person_of_user)
    end

    private

    def resolve_with_document(person, user_by_email, person_of_user)
      linked_user = person.user

      # Document identifies person A, but the supplied email belongs to a
      # different account than the one linked to A, or to an account already
      # tied to a different person in this org.
      if conflicting_email_account?(person, user_by_email, person_of_user)
        return build(STATUS_CONFLICT, person: person, user: linked_user,
                                      conflict_reason: "email_belongs_to_other_account")
      end

      build(STATUS_PERSON, person: person, user: linked_user || user_by_email)
    end

    def resolve_without_document(user_by_email, person_of_user)
      if user_by_email
        return build(STATUS_PERSON, person: person_of_user, user: user_by_email) if person_of_user

        # Account exists but has no identity in this organization: candidate for
        # incorporation, not a new account.
        return build(STATUS_ACCOUNT, user: user_by_email)
      end

      person_by_email = find_person_by_email
      return build(STATUS_PERSON, person: person_by_email) if person_by_email

      build(STATUS_NONE)
    end

    def conflicting_email_account?(person, user_by_email, person_of_user)
      return false if user_by_email.blank?

      linked_user = person.user
      return true if linked_user.present? && user_by_email.id != linked_user.id
      return true if person_of_user.present? && person_of_user.id != person.id

      false
    end

    def find_person_by_document
      digest = Person.document_digest(@document_number)
      return nil if digest.blank?

      scoped_people.find_by(document_number_digest: digest)
    end

    def find_person_by_email
      normalized = normalized_email
      return nil if normalized.blank?

      scoped_people.where("metadata->>'import_email' = ?", normalized).first
    end

    def find_user_by_email
      normalized = normalized_email
      return nil if normalized.blank?

      User.where("LOWER(email) = ?", normalized).first
    end

    def normalized_email
      @email.to_s.downcase.strip.presence
    end

    def scoped_people
      Person.where(organization_id: @organization.id)
    end

    def build(status, person: nil, user: nil, conflict_reason: nil)
      Result.new(status: status, person: person, user: user, conflict_reason: conflict_reason)
    end
  end
end
