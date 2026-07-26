# frozen_string_literal: true

module Memberships
  # Revokes a person's membership in one organization. When +unlink_user+ is
  # true (client decline, per property-onboarding), the +User+ is unlinked from
  # the +Person+ so no user access remains, but the +Person+ and its
  # ownerships/occupancies stay owned by the organization. Organization-scoped:
  # other organizations' memberships are unaffected.
  class Revoke
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(membership:, unlink_user: false)
      @membership = membership
      @person = membership.person
      @unlink_user = unlink_user
    end

    def call
      OrganizationMembership.transaction do
        @membership.revoke! if @membership.may_revoke?
        unlink_user if @unlink_user
        @membership
      end
    end

    private

    def unlink_user
      return if @person.user_id.blank?

      @person.update!(user: nil)
    end
  end
end
