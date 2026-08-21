# frozen_string_literal: true

class Api::ErrorsController < ActionController::API
  def not_found
    render json: { error: I18n.t("api.errors.not_found") }, status: :not_found
  end
end
