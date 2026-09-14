# frozen_string_literal: true

# GET /api/v1/private/invitations — visits where the current user is the
# visitor_person, scheduled from the start of today onwards and not cancelled.
# Requires the +view_own_visits+ capability (VisitPolicy::OwnScope).
class Api::V1::Private::InvitationsController < Api::V1::Private::BaseController
  before_action :authorize_own_visits!

  def index
    visits = VisitPolicy::OwnScope.new(current_user, Visit.all).resolve
                                  .where(scheduled_at: Time.zone.now.beginning_of_day..)
                                  .where.not(status: VisitStatuses::CANCELLED)
                                  .includes(:residential_property, :unit, :created_by, :visitor_person)
                                  .order(:scheduled_at)

    render_collection(visits, serializer: Api::Private::InvitationSerializer)
  end

  private

  def authorize_own_visits!
    resolver = Authorization::Resolver.new(user: current_user, organization: ActsAsTenant.current_tenant)
    return if resolver.allowed?(Authorization::Capabilities::VIEW_OWN_VISITS)

    render json: { error: I18n.t("api.errors.forbidden") }, status: :forbidden
  end
end
