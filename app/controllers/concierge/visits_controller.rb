# frozen_string_literal: true

# Operational controller for concierge-facing visit workflow.
#
# Surfaces: index (operational list scoped to assigned property),
# show (restricted detail), check_in and check_out.
#
# Concierge actors cannot create, update, authorize or cancel (§5.6 / §6.1).
# The policy scope already filters to operational statuses for concierge users.
class Concierge::VisitsController < AdminController
  before_action :set_visit, only: %i[show check_in check_out]

  # GET /concierge/visits (6.1, 6.4)
  # Operational listing: authorized + checked_in + recent checked_out on the active property.
  # When the concierge is assigned to multiple properties the caller must supply
  # ?property_id=<uuid> to pin the context; without it the first authorized property
  # is used. All queries are scoped to a single property (1.1 / 1.2).
  def index
    authorize Visit
    # 2.4 — org+property scope is applied first; search filters are applied after.
    scoped    = property_scoped_visits
    tab_scope = apply_operational_tab(scoped, params[:tab])
    visits    = apply_concierge_search(tab_scope)
                  .includes(:visitor_person, :unit, :checked_in_by, :visit_status_histories)
                  .page(@filters[:page])
                  .per(@filters[:per_page])

    render inertia: "concierge/visits/index", props: {
      visits: serialize_visits(visits),
      pagination: pagination_info(visits),
      tab: operational_tab_param(params[:tab]),
      query: search_query,
      # 2.8 — counters for both operational lists; empty lists return count = 0
      counters: visit_counters(scoped),
      assigned_property: assigned_property_summary
    }
  end

  # GET /concierge/visits/:id (6.1, 6.4)
  def show
    authorize @visit

    render inertia: "concierge/visits/show", props: {
      visit: serialize_summary(@visit)
    }
  end

  # POST /concierge/visits/:id/check_in (6.1, 6.5, 6.6, 6.7)
  def check_in
    Visits::CheckIn.call(
      visit: @visit,
      actor: current_user,
      access_point: check_in_params[:access_point],
      access_type: check_in_params[:access_type],
      vehicle_plate: check_in_params[:vehicle_plate],
      notes: check_in_params[:notes],
      check_in_metadata: check_in_params[:metadata]&.to_h || {}
    )
    redirect_to operational_redirect_target
  rescue AASM::InvalidTransition
    operational_error_redirect(base: [ t("frontend.admin.visits.errors.invalid_transition") ])
  rescue Visits::OperationalMetadataParams::InvalidMetadataError => e
    operational_error_redirect(base: [ e.message ])
  rescue Pundit::NotAuthorizedError
    operational_error_redirect(base: [ t("frontend.admin.visits.errors.not_authorized") ])
  end

  # POST /concierge/visits/:id/check_out (6.1, 6.5, 6.6, 6.7)
  def check_out
    Visits::CheckOut.call(
      visit: @visit,
      actor: current_user,
      access_point: check_out_params[:access_point],
      incident_type: check_out_params[:incident_type],
      notes: check_out_params[:notes],
      check_out_metadata: check_out_params[:metadata]&.to_h || {}
    )
    redirect_to operational_redirect_target
  rescue AASM::InvalidTransition
    operational_error_redirect(base: [ t("frontend.admin.visits.errors.invalid_transition") ])
  rescue Visits::OperationalMetadataParams::InvalidMetadataError => e
    operational_error_redirect(base: [ e.message ])
  rescue Pundit::NotAuthorizedError
    operational_error_redirect(base: [ t("frontend.admin.visits.errors.not_authorized") ])
  end

  private

  def set_visit
    @visit = policy_scope(Visit)
               .includes(:visitor_person, :unit, :checked_in_by, :visit_status_histories)
               .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to concierge_visits_path,
                inertia: { errors: { base: [ t("frontend.admin.visits.errors.not_found") ] } }
  end

  def check_in_params
    p = params[:check_in] ? params.require(:check_in) : ActionController::Parameters.new
    p.permit(:access_point, :access_type, :vehicle_plate, :notes, metadata: {})
  end

  def check_out_params
    p = params[:check_out] ? params.require(:check_out) : ActionController::Parameters.new
    p.permit(:access_point, :incident_type, :notes, metadata: {})
  end

  def serialize_summary(visit)
    Concierge::VisitSummarySerializer.new(visit, current_user: current_user).as_json
  end

  def serialize_visits(visits)
    # 5.3 — denied-result search surfaces non-operable visits (cancelled/expired)
    # with the minimal explanatory serializer; normal lists use the row serializer.
    serializer = params[:include_denied].present? ? Concierge::VisitSearchResultSerializer : Concierge::VisitSerializer
    visits.map { |v| serializer.new(v, current_user: current_user).as_json }
  end

  def visit_counters(scoped)
    {
      expected_today: scoped.expected_today.count,
      currently_inside: scoped.currently_inside.count,
      authorized: scoped.where(status: VisitStatuses::AUTHORIZED).count,
      checked_in: scoped.where(status: VisitStatuses::CHECKED_IN).count,
      recent_checked_out: scoped.recently_checked_out.count
    }
  end

  OPERATIONAL_TABS = {
    "expected_today"     => :expected_today,
    "currently_inside"   => :currently_inside,
    "authorized"         => VisitStatuses::AUTHORIZED,
    "checked_in"         => VisitStatuses::CHECKED_IN,
    "recent_checked_out" => "recent_checked_out"
  }.freeze

  def apply_operational_tab(scope, tab)
    key = operational_tab_param(tab)
    return scope.recently_checked_out if key == "recent_checked_out"
    return scope.expected_today       if key == "expected_today"
    return scope.currently_inside     if key == "currently_inside"

    scope.where(status: OPERATIONAL_TABS.fetch(key))
  end

  def operational_tab_param(tab)
    key = tab.to_s.presence || "expected_today"
    OPERATIONAL_TABS.key?(key) ? key : "expected_today"
  end

  def operational_redirect_target
    return concierge_visits_path if params[:return_to] == "list"

    concierge_visit_path(@visit)
  end

  def operational_error_redirect(errors)
    redirect_to operational_redirect_target, inertia: { errors: errors }
  end

  # 2.4 — Apply Visits::ConciergeSearch when a text query is present.
  # The scope is already org+property scoped; the service only refines it further.
  # include_denied surfaces cancelled/expired results to explain entry denial (2.5).
  def apply_concierge_search(scope)
    return scope if search_query.blank?

    Visits::ConciergeSearch.call(
      scope:          scope,
      query:          search_query,
      organization:   Current.organization,
      include_denied: params[:include_denied].present?
    )
  end

  def search_query
    params.dig(:q, :query).to_s.strip.presence
  end

  # 1.1 — Resolve the single authorized property for this concierge session/screen.
  # When ?property_id is supplied it is validated against the concierge's authorized
  # property set; if absent the sole authorized property is used, or nil when
  # multiple properties require an explicit selection.
  def active_property
    @active_property ||= begin
      resolver     = Authorization::Resolver.new(user: current_user, organization: Current.organization)
      property_ids = resolver.profile
                             .property_capabilities
                             .select { |_, caps| caps.include?(Authorization::Capabilities::VIEW_AUTHORIZED_VISITS) }
                             .keys
      return nil if property_ids.empty?

      if params[:property_id].present?
        ResidentialProperty.find_by(id: params[:property_id]) if property_ids.include?(params[:property_id])
      elsif property_ids.one?
        ResidentialProperty.find_by(id: property_ids.first)
      else
        # Multiple authorized properties — caller must supply property_id.
        nil
      end
    end
  end

  def assigned_property_summary
    return nil unless active_property

    { id: active_property.id, name: active_property.name }
  end

  # 1.2 — All visit queries are scoped first by VisitPolicy::Scope (organization +
  # concierge_visible), then narrowed to the single active property so lists,
  # counters and mutations never leak data across properties.
  def property_scoped_visits
    base = policy_scope(Visit)
    return base.where(residential_property_id: active_property.id) if active_property

    base
  end
end
