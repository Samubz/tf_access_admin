# frozen_string_literal: true

class Api::V1::Auth::SessionsController < Api::V1::BaseController
  skip_before_action :set_current_organization, only: [ :create ]

  before_action :authenticate_user!, only: [ :destroy ]
  before_action :ensure_destroy_tenant_access!, only: [ :destroy ]

  def create
    organization = get_organization_from_subdomain(api_subdomain_from_request)
    return render json: { error: I18n.t("api.errors.unauthorized_tenant") }, status: :unauthorized if organization.blank?

    user = ActsAsTenant.without_tenant do
      User.find_for_authentication(
        email: params[:email],
        organization_id: organization.id
      )
    end

    unless user&.valid_password?(params[:password])
      return render json: { error: I18n.t("api.errors.invalid_credentials") }, status: :unauthorized
    end

    person = ActsAsTenant.without_tenant { user.person_for(organization) }
    unless user.super_admin? || person&.has_role?(AvailableRoles::TENANT_ADMIN, organization)
      return render json: { error: I18n.t("api.errors.forbidden") }, status: :forbidden
    end

    if user.respond_to?(:confirmed?) && !user.confirmed?
      return render json: { error: I18n.t("api.errors.unconfirmed_account") }, status: :unauthorized
    end

    if user.deactivated_at.present?
      return render json: { error: I18n.t("api.errors.account_deactivated") }, status: :unauthorized
    end

    Current.organization = organization
    ActsAsTenant.with_tenant(organization) do
      sign_in(user, store: false)
    end

    token = request.env[Warden::JWTAuth::Hooks::PREPARED_TOKEN_ENV_KEY]
    unless token
      return render json: { error: I18n.t("api.errors.token_dispatch_failed") }, status: :internal_server_error
    end

    Current.reset

    render json: {
      data: {
        token: token,
        token_type: "Bearer",
        expires_in: Warden::JWTAuth.config.expiration_time,
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          role: ActsAsTenant.with_tenant(organization) { user.tenant_role || user.role }
        }
      }
    }, status: :ok
  end

  def destroy
    sign_out(current_user)
    head :no_content
  end

  private

  def ensure_destroy_tenant_access!
    return if current_user.super_admin?

    return if current_user.member_of_tenant?(ActsAsTenant.current_tenant)

    render json: { error: I18n.t("api.errors.forbidden") }, status: :forbidden
    nil
  end
end
