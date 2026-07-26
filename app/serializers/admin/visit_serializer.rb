# frozen_string_literal: true

# Administrative list serializer for Visit (§7.1, §7.4).
# Used in Admin::VisitsController#index and as a base for the detail serializers.
# Embeds minimal person/unit/property labels so the frontend can render rows
# without issuing additional requests. Permissions and actions are always
# backend-calculated from the current policy (§7.9).
class Admin::VisitSerializer < ActiveModel::Serializer
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
    :created_at,
    :updated_at,
    :visitor,
    :authorizers,
    :unit,
    :residential_property,
    :notification_status,
    :notification_status_label,
    :permissions,
    :actions

  def status_label
    I18n.t("frontend.admin.visits.statuses.#{object.status}", default: object.status.to_s.humanize)
  end

  def notification_status
    object.notification_status
  end

  def notification_status_label
    I18n.t(
      "frontend.admin.visits.notification_statuses.#{object.notification_status}",
      default: object.notification_status.to_s.humanize
    )
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

  def residential_property
    property = object.residential_property
    return nil unless property

    { id: property.id, name: property.name }
  end

  def permissions
    @permissions ||= begin
      policy = build_policy
      {
        show: policy.show?,
        create: policy.create?,
        update: policy.update?,
        authorize: policy.authorize?,
        cancel: policy.cancel?,
        resend_notification: policy.resend_notification?,
        check_in: policy.check_in?,
        check_out: policy.check_out?,
        full_detail: policy.full_detail?,
        restricted_detail: policy.restricted_detail?
      }
    end
  end

  def actions
    permissions.filter_map { |action, allowed| action.to_s if allowed }
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
