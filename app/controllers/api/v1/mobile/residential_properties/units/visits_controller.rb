# frozen_string_literal: true

class Api::V1::Mobile::ResidentialProperties::Units::VisitsController < Api::V1::Mobile::BaseController
  def index
    result = Mobile::ResidentialProperties::Units::Visits::Index.call(
      user: current_user,
      residential_property_id: params[:id],
      unit_id: params[:unit_id],
      day: params[:day]
    )

    case result
    when nil
      raise ActiveRecord::RecordNotFound
    when :invalid_day
      render json: { error: I18n.t("api.errors.invalid_day") }, status: :unprocessable_entity
    else
      render json: { data: result }, status: :ok
    end
  end
end
