# frozen_string_literal: true

# GET /api/v1/private/units — units where the current person holds an active
# occupancy or ownership in the current organization.
class Api::V1::Private::UnitsController < Api::V1::Private::BaseController
  def index
    person = current_user.person_for(ActsAsTenant.current_tenant)
    units = Unit.with_active_relationship_for(person, ActsAsTenant.current_tenant)
                .includes(:organization)
                .order(:identifier)

    render_collection(units, serializer: Api::Private::UnitSerializer)
  end
end
