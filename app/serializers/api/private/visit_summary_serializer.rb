# frozen_string_literal: true

# Compact visit payload for GET /api/v1/private/units/:unit_id/visits?day=.
class Api::Private::VisitSummarySerializer < ActiveModel::Serializer
  attributes :id, :visitor_name, :status, :scheduled_at, :checked_in_at, :checked_out_at

  def visitor_name
    object.visitor_person&.display_name
  end
end
