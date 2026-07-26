# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?
    allowed?(:manage_users)
  end

  def show?
    allowed?(:manage_users) && same_organization?
  end

  def new?
    create?
  end

  def create?
    allowed?(:manage_users)
  end

  def edit?
    update?
  end

  def update?
    allowed?(:manage_users) && same_organization?
  end

  def destroy?
    allowed?(:manage_users) && same_organization?
  end

  class Scope < ApplicationPolicy::Scope
    include PolicyScopeAuthorization

    def resolve
      return scope.none unless user.present?

      org = current_organization
      return scope.none unless org
      return scope.none unless authorization_resolver&.allowed?(:manage_users)

      scope.joins(:people).where(people: { organization_id: org.id }).distinct
    end
  end
end
