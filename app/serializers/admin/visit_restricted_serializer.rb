# frozen_string_literal: true

# Restricted detail serializer for Visit (§7.6).
# Used in Admin::VisitsController#show when policy.restricted_detail? is true
# and policy.full_detail? is false.
# Exposes only the fields needed for access-control operations:
# visitor identity, unit, host, status, relevant timestamps, and allowed actions.
# Administrative data (notes, metadata, actor details, history) are omitted.
class Admin::VisitRestrictedSerializer < ActiveModel::Serializer
  include VisitAuthorizersSerialization

  attributes :id,
    :status,
    :status_label,
    :visit_type,
    :visit_type_label,
    :scheduled_at,
    :valid_from,
    :valid_until,
    :authorized_at,
    :checked_in_at,
    :checked_out_at,
    :residential_property_id,
    :unit_id,
    :visitor_person_id,
    :visitor,
    :authorizers,
    :unit,
    :residential_property,
    :permissions,
    :actions,
    :history

  def status_label
    I18n.t("frontend.admin.visits.statuses.#{object.status}", default: object.status.to_s.humanize)
  end

  def visit_type_label
    return nil if object.visit_type.blank?

    I18n.t("frontend.admin.visits.visit_types.#{object.visit_type}", default: object.visit_type.to_s.humanize)
  end

  def visitor
    person_summary(object.visitor_person)
  end

  def unit
    u = object.unit
    return nil unless u

    { id: u.id, identifier: u.identifier, display_name: u.display_name }
  end

  def permissions
    @permissions ||= begin
      policy = build_policy
      {
        show: policy.show?,
        check_in: policy.check_in?,
        check_out: policy.check_out?,
        restricted_detail: policy.restricted_detail?
      }
    end
  end

  def actions
    permissions.filter_map { |action, allowed| action.to_s if allowed }
  end

  def residential_property
    property = object.residential_property
    return nil unless property

    { id: property.id, name: property.name }
  end

  def history
    object.visit_status_histories.map do |event|
      Admin::VisitStatusHistorySerializer.new(event).as_json
    end
  end

  private

  def build_policy
    @instance_options[:policy] || VisitPolicy.new(current_user, object)
  end

  def current_user
    @instance_options[:current_user] || scope
  end

  def person_summary(person)
    return nil unless person

    { id: person.id, display_name: person.display_name }
  end
end
