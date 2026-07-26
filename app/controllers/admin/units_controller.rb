# frozen_string_literal: true

# Organization-wide unit catalog and search (improve-units-foundation §6.7–§6.9).
# Mutations live in the nested property channel
# (Admin::ResidentialProperties::UnitsController).
class Admin::UnitsController < AdminController
  def index
    authorize Unit

    units = Units::Search.apply(
      policy_scope(Unit).includes(:residential_property, :property_section),
      term: search_term,
      residential_property_id: params.dig(:q, :residential_property_id),
      property_section_id: params.dig(:q, :property_section_id),
      status: params.dig(:q, :status)
    )
      .order(:identifier)
      .page(@filters[:page])
      .per(@filters[:per_page])

    render json: {
      units: units.map { |unit| serialize_unit_summary(unit) },
      pagination: pagination_info(units)
    }
  end

  private

  def search_term
    params.dig(:q, :search).presence || params[:search].presence
  end

  def serialize_unit_summary(unit)
    Admin::UnitSummarySerializer.new(unit, current_user: current_user).as_json
  end
end
