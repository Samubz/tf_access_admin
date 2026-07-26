# frozen_string_literal: true

module Visits
  # Manually retries push delivery for a visit whose notification_status is
  # "failed". Retries the SAME original residents from the visit's existing
  # Notification rows — it does not re-resolve current active unit authorizers.
  # See openspec/changes/add-fcm-push-notifications/design.md Decision 7.
  class ResendNotification
    include ServiceAuthorization

    class NotFailedError < StandardError; end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(visit:, actor:)
      @visit = visit
      @actor = actor
    end

    def call
      # Checked before authorization so this specific, clearer error always
      # surfaces for a wrong-state visit — independent of the VisitPolicy's
      # own notification_status gate (used separately to hide/show the resend
      # UI action; see VisitPolicy#resend_notification?).
      raise NotFailedError unless @visit.notification_status == Visit::NotificationStatuses::FAILED

      authorize_visit_action!(@visit, :resend_notification?)

      resent = ActiveRecord::Base.transaction do
        @visit.update!(notification_status: Visit::NotificationStatuses::PENDING)
        # Individual #update! (not #update_all) so `audited` records each
        # reset-to-pending as its own history entry (design.md Decision 7).
        notifications.to_a.each { |notification| notification.update!(status: NotificationStatuses::PENDING, last_error: nil) }
      end

      resent.each { |notification| DeliverPushNotificationJob.perform_later(notification.id) }

      @visit
    end

    private

    def notifications
      @notifications ||= @visit.notifications.where(notification_type: NotificationTypes::VISIT_REQUEST)
    end
  end
end
