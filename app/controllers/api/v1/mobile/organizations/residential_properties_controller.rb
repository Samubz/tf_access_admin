# frozen_string_literal: true

class Api::V1::Mobile::Organizations::ResidentialPropertiesController < Api::V1::Mobile::BaseController
  def show
    result = Mobile::Organizations::ResidentialProperties::Detail.call(
      user: current_user,
      organization_id: params[:organization_id],
      residential_property_id: params[:id]
    )
    raise ActiveRecord::RecordNotFound if result.blank?

    render json: { data: result }, status: :ok
  end
end
