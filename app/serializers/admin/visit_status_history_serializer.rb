# frozen_string_literal: true

class Admin::VisitStatusHistorySerializer < ActiveModel::Serializer
  attributes :id,
    :event_type,
    :event_type_label,
    :from_status,
    :from_status_label,
    :to_status,
    :to_status_label,
    :occurred_at,
    :notes,
    :metadata,
    :actor_user_id,
    :actor_name,
    :actor_email

  def event_type_label
    I18n.t(
      "frontend.admin.visits.event_types.#{object.event_type}",
      default: object.event_type.to_s.humanize
    )
  end

  def from_status_label
    status_label(object.from_status)
  end

  def to_status_label
    status_label(object.to_status)
  end

  def actor_user_id
    object.actor_user_id
  end

  def actor_name
    object.actor_user&.name
  end

  def actor_email
    object.actor_user&.email
  end

  private

  def status_label(status)
    return nil if status.blank?

    I18n.t(
      "frontend.admin.visits.statuses.#{status}",
      default: status.to_s.humanize
    )
  end
end
