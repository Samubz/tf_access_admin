# frozen_string_literal: true

module BulkImportServices
  # Classifies a single people-import row against existing identities, without
  # merging or mutating anything (bulk-import-people spec). It delegates identity
  # resolution to +People::ResolveIdentityMatch+ and inspects existing
  # membership / pending onboarding requests to detect already-satisfied rows.
  #
  # Additive: this does not change the current +ImportPeopleRow+ importer. Wiring
  # the classifier into the import pipeline is a follow-up.
  class ClassifyPeopleRow
    READY_TO_CREATE_PERSON = :ready_to_create_person
    REQUIRES_INVITATION    = :requires_invitation
    REQUIRES_INCORPORATION = :requires_incorporation
    CONFLICT               = :conflict
    DUPLICATE              = :duplicate
    INVALID                = :invalid

    Result = Data.define(:classification, :person, :user) do
      def invalid?  = classification == INVALID
      def conflict? = classification == CONFLICT
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
      return build(INVALID) if @email.blank? && @document_number.blank?

      match = resolve_identity
      return build(CONFLICT) if match.conflict?

      case match.status
      when People::ResolveIdentityMatch::STATUS_NONE    then build(READY_TO_CREATE_PERSON)
      when People::ResolveIdentityMatch::STATUS_ACCOUNT then build(REQUIRES_INCORPORATION, user: match.user)
      when People::ResolveIdentityMatch::STATUS_PERSON  then classify_existing_person(match)
      end
    end

    private

    def resolve_identity
      People::ResolveIdentityMatch.call(
        organization: @organization,
        email: @email,
        document_number: @document_number
      )
    end

    def classify_existing_person(match)
      person = match.person
      return build(DUPLICATE, person: person, user: match.user) if already_satisfied?(person)

      classification = person.user_id.present? ? REQUIRES_INCORPORATION : REQUIRES_INVITATION
      build(classification, person: person, user: match.user)
    end

    # Already an active member, or a pending onboarding request exists: the row
    # duplicates work already done or in flight — idempotent, no new action.
    def already_satisfied?(person)
      active_membership?(person) || pending_request?(person)
    end

    def active_membership?(person)
      membership = person.organization_membership
      membership.present? && membership.status.in?(
        [ OrganizationMembership::STATUS_ACTIVE, OrganizationMembership::STATUS_INVITED ]
      )
    end

    def pending_request?(person)
      OnboardingRequest.where(
        organization_id: @organization.id,
        person_id: person.id,
        status: OnboardingRequest::STATUS_PENDING
      ).exists?
    end

    def build(classification, person: nil, user: nil)
      Result.new(classification: classification, person: person, user: user)
    end
  end
end
