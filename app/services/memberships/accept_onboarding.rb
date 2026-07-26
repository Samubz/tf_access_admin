# frozen_string_literal: true

module Memberships
  # Finalizes a pending onboarding request by the holder: activates the
  # membership, links the resolved account to the person, and confirms the
  # operational role (StaffAssignment). Idempotent for an already-accepted
  # request. Client requests are created accepted by +RequestOnboarding+, so
  # this is mainly the operational acceptance path.
  class AcceptOnboarding
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(onboarding_request:)
      @request = onboarding_request
    end

    def call
      OnboardingRequest.transaction do
        @request.accept! if @request.may_accept?

        link_account
        ensure_active_membership

        if operational?
          confirm_operational_roles
        else
          grant_client_role
        end

        @request
      end
    end

    private

    def operational?
      @request.requested_relationship == OnboardingRequest::RELATIONSHIP_STAFF
    end

    def link_account
      return if @request.user.blank? || @request.person.blank?

      Accounts::LinkUserToPerson.call(person: @request.person, user: @request.user)
    end

    def ensure_active_membership
      person = @request.person
      membership = person.organization_membership ||
        OrganizationMembership.create!(organization: @request.organization, person: person)
      membership.accept! if membership.may_accept?
      membership
    end

    def grant_client_role
      person = @request.person
      person.add_role(AvailableRoles::CLIENT) unless person.has_role?(AvailableRoles::CLIENT)
    end

    def confirm_operational_roles
      scope = StaffAssignment.where(
        organization_id: @request.organization_id,
        person_id: @request.person_id,
        confirmation_state: StaffAssignment::CONFIRMATION_PENDING
      )
      scope = scope.where(residential_property_id: @request.residential_property_id) if @request.residential_property_id

      scope.find_each(&:confirm!)
    end
  end
end
