# frozen_string_literal: true

class Api::V1::Mobile::Auth::SessionsController < Api::V1::Mobile::BaseController
  skip_before_action :authenticate_user!, only: [ :create ]

  def create
    user = User.find_by(email: params[:email])

    unless user&.valid_password?(params[:password])
      return render json: { error: I18n.t("api.errors.invalid_credentials") }, status: :unauthorized
    end

    if user.respond_to?(:confirmed?) && !user.confirmed?
      return render json: { error: I18n.t("api.errors.unconfirmed_account") }, status: :unauthorized
    end

    if user.deactivated_at.present?
      return render json: { error: I18n.t("api.errors.account_deactivated") }, status: :unauthorized
    end

    unless user.client_global?
      return render json: { error: I18n.t("api.errors.forbidden") }, status: :forbidden
    end

    sign_in(user, store: false)

    token = request.env[Warden::JWTAuth::Hooks::PREPARED_TOKEN_ENV_KEY]
    unless token
      return render json: { error: I18n.t("api.errors.token_dispatch_failed") }, status: :internal_server_error
    end

    render json: {
      data: {
        token: token,
        token_type: "Bearer",
        expires_in: Warden::JWTAuth.config.expiration_time,
        user: {
          id: user.id,
          email: user.email,
          name: user.name
        }
      }
    }, status: :ok
  end

  def destroy
    sign_out(current_user)
    head :no_content
  end
end
