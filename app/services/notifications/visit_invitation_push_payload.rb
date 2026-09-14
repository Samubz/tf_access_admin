# frozen_string_literal: true

module Notifications
  # Builds the title/body/data for a visit-invitation push addressed to the
  # visitor (D4). Texts are localized in the recipient user's language and the
  # data payload lets the mobile client deep-link to the invitation.
  class VisitInvitationPushPayload
    def self.build(notification)
      new(notification).build
    end

    def initialize(notification)
      @notification = notification
      @visit = notification.notifiable
    end

    def build
      property_name = @notification.residential_property&.name || @visit.residential_property&.name

      I18n.with_locale(recipient_locale) do
        {
          title: I18n.t("notifications.visit_invitation.title"),
          body: I18n.t(
            "notifications.visit_invitation.body",
            property: property_name,
            date: I18n.l(@visit.scheduled_at, format: :short)
          ),
          data: {
            type: NotificationTypes::VISIT_INVITATION,
            visit_id: @visit.id,
            residential_property_name: property_name,
            unit_identifier: @notification.unit&.identifier || @visit.unit&.identifier,
            scheduled_at: @visit.scheduled_at&.iso8601
          }
        }
      end
    end

    private

    def recipient_locale
      @notification.recipient_person&.user&.language.presence || I18n.default_locale
    end
  end
end
