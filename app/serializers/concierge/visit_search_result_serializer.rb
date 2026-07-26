# frozen_string_literal: true

# Minimal, non-operable search result for concierge (§2.5 / §5.3).
#
# Surfaced only via the denied-result search path (cancelled or lapsed visits)
# to explain why entry is refused. It exposes the bare minimum needed for that
# explanation: no actions, no permissions, no person profile, no timeline.
class Concierge::VisitSearchResultSerializer < ActiveModel::Serializer
  attributes :id,
    :status,
    :effective_status,
    :effective_status_label,
    :scheduled_at,
    :visitor,
    :unit,
    :denial_reason,
    :denial_explanation,
    :actions,
    :permissions

  def effective_status
    object.effective_operational_status
  end

  def effective_status_label
    I18n.t("frontend.admin.visits.statuses.#{effective_status}", default: effective_status.to_s.humanize)
  end

  # Minimal visitor identity: display name only, never the full person profile.
  def visitor
    person = object.visitor_person
    return nil unless person

    { id: person.id, display_name: person.display_name }
  end

  def unit
    u = object.unit
    return nil unless u

    { id: u.id, identifier: u.identifier, display_name: u.display_name }
  end

  # Why this visit cannot be checked in, keyed off the effective status.
  def denial_reason
    case effective_status
    when VisitStatuses::CANCELLED then "cancelled"
    when VisitStatuses::EXPIRED   then "expired"
    else "not_operable"
    end
  end

  def denial_explanation
    I18n.t("frontend.concierge.visits.denial.#{denial_reason}")
  end

  # Non-operable: never offers an action.
  def actions
    []
  end

  def permissions
    { show: false, check_in: false, check_out: false, restricted_detail: false }
  end
end
