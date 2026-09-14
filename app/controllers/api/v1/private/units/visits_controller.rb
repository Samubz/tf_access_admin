# frozen_string_literal: true

# GET  /api/v1/private/units/:unit_id/visits?day=YYYY-MM-DD
# POST /api/v1/private/units/:unit_id/visits
#
# Private authenticated endpoints for resident visit listing and registration.
# +index+ returns the unit's visits whose scheduled_at falls on +day+ in the
# property's time zone; +day+ missing or invalid → 422.
# Distinct from the administrative Inertia visit flow.
#
# This endpoint creates visits exclusively in `authorized` status.
# Only residents with an active unit relationship and `authorize_visits`
# capability may use it. A `pending` visit flow requires a separate contract.
#
# Accepted payload (client-supplied):
#   unit_id       – path param; resolved tenant-safely from current organization
#   visitor.name     – visitor full name (required)
#   visitor.email    – visitor email (required, valid format; identity key
#                      within the organization — see D3)
#   visitor.document – visitor identity document (optional)
#   visitor.phone    – visitor phone number (optional)
#   scheduled_at  – ISO 8601 datetime
#
# NOT accepted from client (resolved in backend):
#   organization_id, residential_property_id, property_section_id,
#   created_by_id, authorized_by_id, status
class Api::V1::Private::Units::VisitsController < Api::V1::Private::BaseController
  before_action :load_unit
  before_action :authorize_resident!
  before_action :validate_visitor!, only: :create

  def index
    day = parse_day
    return render json: { error: I18n.t("api.errors.invalid_day") }, status: :unprocessable_entity if day.nil?

    visits = @unit.visits
                  .where(scheduled_at: day_range(day))
                  .includes(:visitor_person)
                  .order(:scheduled_at)

    render_collection(visits, serializer: Api::Private::VisitSummarySerializer)
  end

  def create
    visit = Residents::CreateAuthorizedVisit.call(
      unit:           @unit,
      visitor_params: visit_params[:visitor],
      scheduled_at:   visit_params[:scheduled_at],
      actor:          current_user
    )

    render json: { data: { id: visit.id, status: visit.status } }, status: :created
  rescue Visits::ResolveVisitorPerson::IdentityConflict
    render json: { error: I18n.t("api.visits.identity_conflict") }, status: :unprocessable_entity
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

  DAY_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/

  def parse_day
    raw = params[:day].to_s
    return nil unless raw.match?(DAY_FORMAT)

    Date.strptime(raw, "%Y-%m-%d")
  rescue Date::Error
    nil
  end

  def day_range(day)
    zone = ActiveSupport::TimeZone[@unit.residential_property.timezone.to_s] || Time.zone
    zone.local(day.year, day.month, day.day).all_day
  end

  # D3 — name and email are required; email must be well-formed.
  # document and phone are optional.
  def validate_visitor!
    visitor = visit_params[:visitor].to_h
    name    = visitor[:name].to_s.strip
    email   = visitor[:email].to_s.strip
    return if name.present? && email.match?(URI::MailTo::EMAIL_REGEXP)

    render json: { error: I18n.t("api.visits.invalid_visitor") }, status: :unprocessable_entity
  end

  def visit_params
    params.require(:visit).permit(
      :scheduled_at,
      visitor: %i[name email document phone]
    )
  end
end
