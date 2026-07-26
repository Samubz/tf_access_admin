# frozen_string_literal: true

# Delivers a single push Notification to its recipient's device token, then
# rolls up the outcome into the associated Visit's aggregate
# notification_status.
#
# Runs at most once per enqueue: Sidekiq's automatic retry is explicitly
# disabled (retry: false). The only retry path for a failed delivery is the
# operator-triggered manual resend (Visits::ResendNotification) — see
# openspec/changes/add-fcm-push-notifications/design.md Decision 5.
class DeliverPushNotificationJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: false

  def perform(notification_id)
    # Looked up without an ambient tenant first: Sidekiq reuses threads across
    # jobs, so `ActsAsTenant.current_tenant` may hold a stale value left over
    # from a previous, unrelated job on this thread. Establishing the tenant
    # from the notification's OWN organization, only after resolving it
    # tenant-agnostically, avoids `.find` failing (or silently scoping wrong)
    # if the thread's leftover tenant does not match this notification's org.
    notification = ActsAsTenant.without_tenant { Notification.find(notification_id) }

    ActsAsTenant.with_tenant(notification.organization) do
      deliver!(notification)
      update_visit_notification_status!(notification)
    end
  end

  private

  def deliver!(notification)
    device_token = notification.recipient_person.user&.device_token

    if device_token.nil?
      notification.update!(status: NotificationStatuses::SKIPPED)
      return
    end

    payload = Notifications::VisitRequestPushPayload.build(notification)
    result = Fcm::Client.new.send_notification(
      token: device_token.token,
      title: payload[:title],
      body: payload[:body],
      data: payload[:data]
    )

    notification.attempts_count += 1
    if result.success?
      notification.status = NotificationStatuses::SENT
      notification.sent_at = Time.current
      notification.last_error = nil
    else
      notification.status = NotificationStatuses::FAILED
      notification.last_error = result.error_message
    end
    notification.save!
  end

  # Because this project only uses open-source Sidekiq (no Batch API), each
  # job re-evaluates the visit's sibling notifications on completion, under a
  # row lock, so only one of several concurrently-finishing jobs performs the
  # final aggregate write (see design.md Decision 7).
  def update_visit_notification_status!(notification)
    visit = notification.notifiable
    return unless visit.is_a?(Visit)

    Visit.transaction do
      locked_visit = Visit.lock.find(visit.id)
      visit_notifications = locked_visit.notifications.where(notification_type: NotificationTypes::VISIT_REQUEST)

      next if visit_notifications.exists?(status: NotificationStatuses::PENDING)

      new_status =
        if visit_notifications.exists?(status: NotificationStatuses::SENT)
          Visit::NotificationStatuses::DELIVERED
        elsif visit_notifications.exists?(status: NotificationStatuses::FAILED)
          Visit::NotificationStatuses::FAILED
        else
          Visit::NotificationStatuses::NO_RECIPIENTS
        end

      locked_visit.update!(notification_status: new_status)
    end
  end
end
