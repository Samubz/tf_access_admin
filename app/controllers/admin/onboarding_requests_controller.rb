# frozen_string_literal: true

class Admin::OnboardingRequestsController < AdminController
  before_action :set_request, only: [ :revoke, :resolve_conflict ]

  def revoke
    authorize @onboarding_request, :revoke?
    @onboarding_request.revoke! if @onboarding_request.may_revoke?
    redirect_to admin_people_path
  end

  def resolve_conflict
    authorize @onboarding_request, :resolve_conflict?
    IdentityConflicts::Resolve.call(
      onboarding_request: @onboarding_request,
      decision: :dismiss,
      resolved_by: current_user.person_for(current_organization)
    )
    redirect_to admin_people_path
  end

  private

  def set_request
    @onboarding_request = policy_scope(OnboardingRequest).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_people_path,
                inertia: { errors: { base: [ "admin.onboarding_requests.errors.not_found" ] } }
  end

  def current_organization
    Current.organization || ActsAsTenant.current_tenant
  end
end
