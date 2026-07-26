# frozen_string_literal: true

# POST /api/v1/private/units/:unit_id/visits
#
# Private authenticated endpoint for resident visit registration.
# Distinct from the administrative Inertia visit flow.
#
# This endpoint creates visits exclusively in `authorized` status.
# Only residents with an active unit relationship and `authorize_visits`
# capability may use it. A `pending` visit flow requires a separate contract.
#
# Accepted payload (client-supplied):
#   unit_id       – path param; resolved tenant-safely from current organization
#   visitor.name  – visitor full name
#   visitor.document – visitor identity document
#   visitor.phone – visitor phone number
#   scheduled_at  – ISO 8601 datetime
#
# NOT accepted from client (resolved in backend):
#   organization_id, residential_property_id, property_section_id,
#   created_by_id, authorized_by_id, status
class Api::V1::Private::Units::VisitsController < Api::V1::Private::BaseController
  before_action :load_unit
  before_action :authorize_resident!

  def create
    visit = Residents::CreateAuthorizedVisit.call(
      unit:           @unit,
      visitor_params: visit_params[:visitor],
      scheduled_at:   visit_params[:scheduled_at],
      actor:          current_user
    )

    render json: { data: { id: visit.id, status: visit.status } }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  # 2.2 — Unit is loaded through ActsAsTenant scope: any unit_id outside the
  # current organization raises RecordNotFound (rescued as 404 in BaseController).
  def load_unit
    @unit = Unit.find(params[:unit_id])
  end

  # 2.1 / 2.3–2.7 — Resolves User → Person → unit capabilities and enforces
  # that the resident has both create_visits and authorize_visits on @unit.
  # Inactive, expired, future-dated, or soft-deleted relationships produce 403,
  # as does UnitOccupancy with can_authorize_visits = false.
  def authorize_resident!
    @visit_context = Residents::VisitContext.new(
      user: current_user,
      organization: ActsAsTenant.current_tenant,
      unit: @unit
    )

    return if @visit_context.authorized?

    render json: { error: I18n.t("api.visits.#{@visit_context.denial_reason}") },
           status: :forbidden
  end

  def visit_params
    params.require(:visit).permit(
      :scheduled_at,
      visitor: %i[name document phone]
    )
  end
end
