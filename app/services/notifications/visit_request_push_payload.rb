# frozen_string_literal: true

module Notifications
  # Builds the title/body/data for a visit-request push notification.
  #
  # The `data` payload includes enough for a mobile client to deep-link to the
  # visit without an extra API round-trip (openspec/changes/add-fcm-push-notifications
  # design.md Decision 4).
  class VisitRequestPushPayload
    def self.build(notification)
      new(notification).build
    end

    def initialize(notification)
      @notification = notification
      @visit = notification.notifiable
    end

    def build
      {
        title: I18n.t("frontend.notifications.visit_request.title"),
        body: I18n.t(
          "frontend.notifications.visit_request.body",
          visitor_name: @visit.visitor_person.display_name,
          unit_identifier: @notification.unit&.identifier
        ),
        data: {
          type: NotificationTypes::VISIT_REQUEST,
          visit_id: @visit.id,
          residential_property_name: @notification.residential_property&.name,
          unit_identifier: @notification.unit&.identifier,
          visitor_name: @visit.visitor_person.display_name
        }
      }
    end
  end
end
