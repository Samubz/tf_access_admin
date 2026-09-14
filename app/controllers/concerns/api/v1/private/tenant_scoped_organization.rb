# frozen_string_literal: true

# Shared guard for /organization/:id endpoints: the path id must be the current
# tenant (404 otherwise) and resident relationships are resolved once per request.
module Api::V1::Private::TenantScopedOrganization
  extend ActiveSupport::Concern

  included do
    before_action :ensure_organization_matches_tenant!
  end

  private

  def current_organization
    ActsAsTenant.current_tenant
  end

  def ensure_organization_matches_tenant!
    raise ActiveRecord::RecordNotFound unless params[:id].to_s == current_organization.id.to_s
  end

  def resident_relationships
    @resident_relationships ||= Api::Private::ResidentRelationships.new(
      person: current_user.person_for(current_organization),
      organization: current_organization
    )
  end
end
