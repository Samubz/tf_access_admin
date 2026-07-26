# frozen_string_literal: true

module Notifications
  # Creates one push Notification per active resident authorizer of a visit's
  # unit (UnitOccupancy#can_authorize_visits), and enqueues one
  # DeliverPushNotificationJob per resident. Pure local DB work — no external
  # I/O — so it runs synchronously right after visit creation, not as a job
  # itself. See openspec/changes/add-fcm-push-notifications/design.md Decision 5.
  class CreateForVisit
    def self.call(visit:)
      new(visit:).call
    end

    def initialize(visit:)
      @visit = visit
    end

    def call
      authorizers = UnitOccupancy.active_authorizers_for(@visit.unit).includes(:person)

      if authorizers.none?
        @visit.update!(notification_status: Visit::NotificationStatuses::NO_RECIPIENTS)
        return
      end

      authorizers.each do |occupancy|
        notification = Notification.create!(
          organization: @visit.organization,
          recipient_person: occupancy.person,
          unit: @visit.unit,
          residential_property: @visit.residential_property,
          notifiable: @visit,
          notification_type: NotificationTypes::VISIT_REQUEST,
          channel: NotificationChannels::PUSH,
          status: NotificationStatuses::PENDING
        )
        DeliverPushNotificationJob.perform_later(notification.id)
      end
    end
  end
end
