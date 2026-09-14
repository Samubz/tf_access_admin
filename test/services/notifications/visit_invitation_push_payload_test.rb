# frozen_string_literal: true

require "test_helper"

module Notifications
  # fcm-push-notifications "Visit invitation push payload".
  class VisitInvitationPushPayloadTest < ActiveSupport::TestCase
    include OperationalPolicyTestHelper

    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization
      Current.organization = @organization

      @property = create_property(@organization, "Payload Property")
      @unit = create_unit(@property, "VIP-101")
      @visitor_user = create_user_for_organization(
        organization: @organization,
        email: "vip-visitor@example.test",
        role: AvailableRoles::VISITOR
      )
      @visitor_user.update!(language: Languages::PT)
      @visitor_person = @visitor_user.person_for(@organization)
      @visit = Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: @visitor_person,
        scheduled_at: Time.zone.parse("2026-09-20 15:30"),
        status: VisitStatuses::AUTHORIZED,
        visit_type: VisitTypes::GUEST
      )
      @notification = Notification.create!(
        organization: @organization,
        recipient_person: @visitor_person,
        unit: @unit,
        residential_property: @property,
        notifiable: @visit,
        notification_type: NotificationTypes::VISIT_INVITATION,
        channel: NotificationChannels::PUSH,
        status: NotificationStatuses::PENDING
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
      Current.reset
    end

    test "payload deep-links to the invitation and is localized in the recipient's language" do
      payload = VisitInvitationPushPayload.build(@notification)

      assert_equal NotificationTypes::VISIT_INVITATION, payload[:data][:type]
      assert_equal @visit.id, payload[:data][:visit_id]
      assert_equal "Payload Property", payload[:data][:residential_property_name]
      assert_equal "VIP-101", payload[:data][:unit_identifier]
      assert_equal @visit.scheduled_at.iso8601, payload[:data][:scheduled_at]

      expected_date = I18n.with_locale(:pt) { I18n.l(@visit.scheduled_at, format: :short) }
      assert_equal I18n.t("notifications.visit_invitation.title", locale: :pt), payload[:title]
      assert_equal I18n.t("notifications.visit_invitation.body", locale: :pt,
                          property: "Payload Property", date: expected_date), payload[:body]
      refute_equal I18n.t("notifications.visit_invitation.title", locale: :es), payload[:title]
    end
  end
end
