# frozen_string_literal: true

# Minimal operational timeline entry for concierge check-out drawer (§9.5).
class Concierge::VisitTimelineEntrySerializer < ActiveModel::Serializer
  attributes :id,
    :event_type,
    :event_type_label,
    :occurred_at,
    :actor_name,
    :tone

  def event_type_label
    I18n.t(
      "frontend.concierge.visits.timeline.events.#{object.event_type}",
      default: I18n.t("frontend.admin.visits.event_types.#{object.event_type}", default: object.event_type.to_s.humanize)
    )
  end

  def actor_name
    object.actor_user&.name
  end

  def tone
    case object.event_type
    when VisitEventTypes::CHECKED_IN
      "success"
    when VisitEventTypes::CHECKED_OUT
      "neutral"
    else
      "neutral"
    end
  end
end
