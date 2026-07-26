# frozen_string_literal: true

module Memberships
  # Creates an onboarding request for an existing/resolved person and applies the
  # join-activation rule (property-onboarding):
  #
  # - client (transversal, self-scoped) → membership active immediately,
  #   declinable; the request is recorded as accepted for audit/idempotency.
  # - operational (org-specific role) → request stays pending and a pending
  #   (unconfirmed) StaffAssignment is created; access is granted only when the
  #   holder accepts (see +Memberships::AcceptOnboarding+).
  #
  # A detected identity conflict is recorded on the request without changing any
  # association. Idempotent: an equivalent pending/accepted request is reused.
  #
  # Out of scope this slice (returns/raises): brand-new person creation
  # (+People::Create+) and email invitations (+Accounts::InvitePerson+).
  class RequestOnboarding
    class UnsupportedRelationship < StandardError; end

    DEFAULT_EXPIRES_IN = 14.days

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(organization:, person:, requested_relationship:, requested_by_person: nil,
                   residential_property: nil, staff_type: nil, requested_roles: [],
                   expires_in: DEFAULT_EXPIRES_IN)
      @organization = organization
      @person = person
      @relationship = requested_relationship
      @requested_by_person = requested_by_person
      @residential_property = residential_property
      @staff_type = staff_type
      @requested_roles = requested_roles
      @expires_in = expires_in
    end

    def call
      validate_relationship!

      existing = existing_request
      return existing if existing

      match = resolve_identity
      return build_conflict_request(match.conflict_reason) if match.conflict?

      OnboardingRequest.transaction do
        case @relationship
        when OnboardingRequest::RELATIONSHIP_MEMBERSHIP then request_client
        when OnboardingRequest::RELATIONSHIP_STAFF      then request_operational
        end
      end
    end

    private

    def validate_relationship!
      return if [ OnboardingRequest::RELATIONSHIP_MEMBERSHIP, OnboardingRequest::RELATIONSHIP_STAFF ].include?(@relationship)

      raise UnsupportedRelationship,
            "#{@relationship.inspect} is not supported by RequestOnboarding yet"
    end

    def resolve_identity
      People::ResolveIdentityMatch.call(
        organization: @organization,
        email: @person.contact_email,
        document_number: @person.document_number
      )
    end

    def request_client
      ensure_active_membership
      @person.add_role(AvailableRoles::CLIENT) unless @person.has_role?(AvailableRoles::CLIENT)

      create_request(status: OnboardingRequest::STATUS_ACCEPTED,
                     requested_roles: [ AvailableRoles::CLIENT ])
    end

    def request_operational
      create_pending_staff_assignment
      create_request(status: OnboardingRequest::STATUS_PENDING,
                     requested_roles: @requested_roles)
    end

    def ensure_active_membership
      membership = @person.organization_membership ||
        OrganizationMembership.create!(organization: @organization, person: @person)
      membership.accept! if membership.may_accept?
      membership
    end

    def create_pending_staff_assignment
      StaffAssignment.create!(
        organization: @organization,
        person: @person,
        residential_property: @residential_property,
        staff_type: @staff_type,
        status: StaffAssignment::STATUS_ACTIVE,
        confirmation_state: StaffAssignment::CONFIRMATION_PENDING,
        starts_at: Date.current
      )
    end

    def build_conflict_request(reason)
      create_request(status: OnboardingRequest::STATUS_CONFLICT,
                     requested_roles: @requested_roles,
                     conflict_reason: reason)
    end

    def create_request(status:, requested_roles:, conflict_reason: nil)
      OnboardingRequest.create!(
        organization: @organization,
        person: @person,
        user: @person.user,
        residential_property: @residential_property,
        requested_relationship: @relationship,
        requested_roles: requested_roles,
        requested_by_person: @requested_by_person,
        status: status,
        conflict_reason: conflict_reason,
        expires_at: @expires_in.from_now
      )
    end

    def existing_request
      OnboardingRequest.where(
        organization_id: @organization.id,
        person_id: @person.id,
        requested_relationship: @relationship,
        residential_property_id: @residential_property&.id,
        status: [ OnboardingRequest::STATUS_PENDING, OnboardingRequest::STATUS_ACCEPTED ]
      ).first
    end
  end
end
