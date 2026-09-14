# frozen_string_literal: true

# GET /api/v1/private/organization/:id/residential_property/:property_id
# One property of the current tenant where the resident has an active
# relationship; any other property (or foreign organization id) is 404.
class Api::V1::Private::Organizations::ResidentialPropertiesController < Api::V1::Private::BaseController
  include Api::V1::Private::TenantScopedOrganization

  def show
    property = resident_relationships.residential_properties.find(params[:property_id])

    render_resource(property,
                    serializer: Api::Private::ResidentialPropertySerializer,
                    relationships: resident_relationships)
  end
end
