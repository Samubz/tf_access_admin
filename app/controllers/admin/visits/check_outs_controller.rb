# frozen_string_literal: true

# POST /admin/visits/:visit_id/check_out (6.1, 6.5, 6.6, 6.7)
#
# Accepts optional operational metadata (access_point, incident_type) alongside
# notes. Delegates to Visits::CheckOut which validates policy, transitions state,
# and records the functional event.
class Admin::Visits::CheckOutsController < AdminController
  def create
    visit = policy_scope(Visit).find(params[:visit_id])
    Visits::CheckOut.call(
      visit: visit,
      actor: current_user,
      access_point: check_out_params[:access_point],
      incident_type: check_out_params[:incident_type],
      notes: check_out_params[:notes],
      check_out_metadata: check_out_params[:metadata]&.to_h || {}
    )
    redirect_to operational_redirect_target(visit)
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_visits_path,
                inertia: { errors: { base: [ t("frontend.admin.visits.errors.not_found") ] } }
  rescue AASM::InvalidTransition
    redirect_to operational_redirect_target(visit),
                inertia: { errors: { base: [ t("frontend.admin.visits.errors.invalid_transition") ] } }
  rescue Visits::OperationalMetadataParams::InvalidMetadataError => e
    redirect_to operational_redirect_target(visit),
                inertia: { errors: { base: [ e.message ] } }
  rescue Pundit::NotAuthorizedError
    redirect_to operational_redirect_target(visit),
                inertia: { errors: { base: [ t("frontend.admin.visits.errors.not_authorized") ] } }
  end

  private

  def operational_redirect_target(visit)
    return admin_visits_path if params[:return_to] == "list"

    admin_visit_path(visit)
  end

  def check_out_params
    p = params[:check_out] ? params.require(:check_out) : ActionController::Parameters.new
    p.permit(:access_point, :incident_type, :notes, metadata: {})
  end
end
