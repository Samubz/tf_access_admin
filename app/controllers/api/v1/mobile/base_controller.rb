# frozen_string_literal: true

class Api::V1::Mobile::BaseController < ActionController::API
  include Pundit::Authorization
  include Devise::Controllers::Helpers

  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  private

  def forbidden
    render json: { error: I18n.t("api.errors.forbidden") }, status: :forbidden
  end

  def not_found
    render json: { error: I18n.t("api.errors.not_found") }, status: :not_found
  end

  def unauthorized
    render json: { error: I18n.t("api.errors.unauthorized") }, status: :unauthorized
  end
end
