# frozen_string_literal: true

module PolicyScopeAuthorization
  extend ActiveSupport::Concern

  private

  def current_organization
    Current.organization || ActsAsTenant.current_tenant
  end

  def authorization_resolver
    @authorization_resolver ||= begin
      org = current_organization
      return nil unless org && user

      if Current.user == user && Current.organization == org
        Current.authorization_resolver
      else
        Authorization::Resolver.new(user: user, organization: org)
      end
    end
  end

  def accessible_property_ids
    authorization_resolver&.accessible_property_ids || []
  end

  def organization_scoped
    org = current_organization
    return scope.none unless org

    scope.where(organization_id: org.id)
  end

  def scoped_to_accessible_properties
    ids = accessible_property_ids
    return scope.none if ids.empty?

    organization_scoped.where(residential_property_id: ids)
  end
end
