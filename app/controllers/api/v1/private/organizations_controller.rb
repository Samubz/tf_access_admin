# frozen_string_literal: true

# GET /api/v1/private/organization/:id — current tenant detail restricted to the
# properties and units where the resident holds an active relationship.
# +:id+ must match the tenant resolved from the subdomain; otherwise 404.
class Api::V1::Private::OrganizationsController < Api::V1::Private::BaseController
  include Api::V1::Private::TenantScopedOrganization

  def show
    render_resource(current_organization,
                    serializer: Api::Private::OrganizationSerializer,
                    relationships: resident_relationships)
  end
end
