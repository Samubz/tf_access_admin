# frozen_string_literal: true

module Accounts
  # Explicitly provisions a per-organization identity for an account: creates the
  # +Person+, an accepted +OrganizationMembership+, and the client role, and
  # optionally applies a tenant role. This replaces the implicit
  # +User#provision_tenant_identity+ after_create hook — provisioning is now an
  # explicit step of admin account creation, so self-registration produces a bare
  # +User+ with no organization identity (person-identity spec, Option B).
  #
  # Idempotent: returns the existing person if one already exists for the org.
  # Must run within the target tenant context.
  class ProvisionTenantIdentity
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(user:, organization:, role: nil)
      @user = user
      @organization = organization
      @role = role
    end

    def call
      person = @user.person_for(@organization) || create_person
      apply_role(person)
      person
    end

    private

    def create_person
      person = @user.people.create!(
        organization: @organization,
        user: @user,
        display_name: @user.name.presence || @user.email,
        status: PersonStatuses::ACTIVE
      )
      membership = OrganizationMembership.create!(organization: @organization, person: person)
      membership.accept! if membership.may_accept?
      person.add_role(AvailableRoles::CLIENT) unless person.has_role?(AvailableRoles::CLIENT)
      person
    end

    def apply_role(person)
      return if @role.blank?

      person.set_tenant_role(@role)
    end
  end
end
