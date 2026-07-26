# frozen_string_literal: true

module Residents
  # Resolves and validates the resident authorization context for visit creation.
  #
  # Encapsulates tasks 2.1–2.7 of the resident private API:
  #   - Resolves the authenticated User and their Person in the active organization (2.1)
  #   - Accepts a tenant-safe Unit already loaded by the caller (2.2)
  #   - Verifies that the Person has an active, currently-valid UnitOccupancy or
  #     UnitOwnership on that unit (2.3 / 2.4) — delegated to GrantProfile via
  #     ActiveRelationships, which enforces status and date bounds
  #   - Requires create_visits AND authorize_visits on that specific unit (2.5)
  #   - Respects can_authorize_visits on occupancies — GrantProfile adds
  #     RESIDENT_AUTHORIZE_VISITS only when the flag is true (2.6)
  #   - Relies on Resolver#cross_organization_context? to block cross-org/cross-unit
  #     escalation (2.7)
  #
  # Usage:
  #   ctx = Residents::VisitContext.new(user: current_user, organization: current_organization, unit: unit)
  #   raise Pundit::NotAuthorizedError unless ctx.authorized?
  class VisitContext
    Result = Data.define(:authorized, :unit, :denial_reason)

    def initialize(user:, organization:, unit:)
      @user         = user
      @organization = organization
      @unit         = unit
    end

    # Returns true only when the user has both create_visits and authorize_visits
    # for the given unit within the current organization. Any inactive, expired,
    # future-dated, or soft-deleted relationship — or a UnitOccupancy with
    # can_authorize_visits = false — produces false.
    def authorized?
      result.authorized
    end

    def denial_reason
      result.denial_reason
    end

    private

    attr_reader :user, :organization, :unit

    def result
      @result ||= resolve
    end

    def resolve
      person = user.person_for(organization)

      unless person
        return Result.new(
          authorized: false,
          unit: unit,
          denial_reason: :no_active_relationship
        )
      end

      resolver = Authorization::Resolver.new(
        user: user,
        organization: organization,
        unit: unit
      )

      can_create    = resolver.allowed?(Authorization::Capabilities::CREATE_VISITS)
      can_authorize = resolver.allowed?(Authorization::Capabilities::AUTHORIZE_VISITS)

      if can_create && can_authorize
        Result.new(authorized: true, unit: unit, denial_reason: nil)
      else
        Result.new(
          authorized: false,
          unit: unit,
          denial_reason: :authorization_denied
        )
      end
    end
  end
end
