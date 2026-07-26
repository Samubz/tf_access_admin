# frozen_string_literal: true

module Memberships
  # Rejects a pending onboarding request. Any pending (unconfirmed) operational
  # role created for the request is deactivated so it grants no access. The
  # person and its unit relationships are left untouched.
  class RejectOnboarding
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(onboarding_request:)
      @request = onboarding_request
    end

    def call
      OnboardingRequest.transaction do
        @request.reject! if @request.may_reject?
        deactivate_pending_operational_roles
        @request
      end
    end

    private

    def deactivate_pending_operational_roles
      return unless @request.requested_relationship == OnboardingRequest::RELATIONSHIP_STAFF

      scope = StaffAssignment.where(
        organization_id: @request.organization_id,
        person_id: @request.person_id,
        confirmation_state: StaffAssignment::CONFIRMATION_PENDING
      )
      scope = scope.where(residential_property_id: @request.residential_property_id) if @request.residential_property_id

      scope.update_all(status: StaffAssignment::STATUS_INACTIVE)
    end
  end
end
