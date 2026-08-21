# frozen_string_literal: true

class Api::V1::Mobile::OrganizationsController < Api::V1::Mobile::BaseController
  def show
    result = Mobile::Organizations::Detail.call(user: current_user, organization_id: params[:id])
    raise ActiveRecord::RecordNotFound if result.blank?

    render json: { data: result }, status: :ok
  end
end
