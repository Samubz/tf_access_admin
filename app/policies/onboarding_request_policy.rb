# frozen_string_literal: true

# Authorization for onboarding requests (normalize-user-identity-and-property-onboarding).
#
# - Inviting/incorporating a person is people management (+manage_people+).
# - Assigning an operational role is manager-only (+manage_staff_assignments+),
#   held by property admins (the "manager" role) and org admins — not concierges,
#   cleaning/internal staff, or plain clients.
# - Resolving a global identity conflict requires the dedicated, super-admin-only
#   +resolve_identity_conflicts+ capability; a property/organization manager must
#   NOT resolve conflicts by virtue of managing people.
#
# Holder-side acceptance (accept/reject an invitation) is authenticated via the
# single-use token flow (+Accounts::AcceptInvitation+), not this policy.
class OnboardingRequestPolicy < ApplicationPolicy
  def create?
    same_organization? && allowed?(Authorization::Capabilities::MANAGE_PEOPLE)
  end

  def revoke?
    create?
  end

  def assign_role?
    same_organization? && allowed?(Authorization::Capabilities::MANAGE_STAFF_ASSIGNMENTS)
  end

  def resolve_conflict?
    allowed?(Authorization::Capabilities::RESOLVE_IDENTITY_CONFLICTS)
  end

  class Scope < ApplicationPolicy::Scope
    include PolicyScopeAuthorization

    def resolve
      return scope.none unless user

      resolver = authorization_resolver
      return scope.none unless resolver&.allowed?(Authorization::Capabilities::MANAGE_PEOPLE)

      organization_scoped
    end
  end
end
