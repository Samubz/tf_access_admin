# frozen_string_literal: true

class Api::V1::Mobile::MeController < Api::V1::Mobile::BaseController
  def show
    render json: {
      data: {
        email: current_user.email,
        name: current_user.name,
        dni: current_user.dni,
        organizations: Mobile::Me::OrganizationsSummary.call(current_user)
      }
    }, status: :ok
  end
end
