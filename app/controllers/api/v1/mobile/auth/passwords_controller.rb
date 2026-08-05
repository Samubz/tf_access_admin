# frozen_string_literal: true

class Api::V1::Mobile::Auth::PasswordsController < Api::V1::Mobile::BaseController
  def update
    if password_params[:password].blank? || password_params[:password_confirmation].blank?
      return render_password_update_failed
    end

    unless current_user.update_with_password(password_params)
      return render_password_update_failed
    end

    # The mobile base controller already authenticated this request via the
    # incoming JWT, so we can't rely on Warden's route-matched dispatch (that
    # mechanism refuses to also validate an incoming token on a route it
    # treats as a dispatch endpoint — see warden_jwt_api_routes.rb). Encode
    # the fresh token directly instead, the same way Hooks#add_token_to_env
    # does internally for login.
    aud = Warden::JWTAuth::EnvHelper.aud_header(request.env)
    token, = Warden::JWTAuth::UserEncoder.new.call(current_user, :user, aud)

    render json: {
      data: {
        token: token,
        token_type: "Bearer",
        expires_in: Warden::JWTAuth.config.expiration_time,
        user: {
          id: current_user.id,
          email: current_user.email,
          name: current_user.name
        }
      }
    }, status: :ok
  end

  private

  def password_params
    params.permit(:current_password, :password, :password_confirmation)
  end

  def render_password_update_failed
    render json: { error: I18n.t("api.errors.password_update_failed") }, status: :unprocessable_entity
  end
end
