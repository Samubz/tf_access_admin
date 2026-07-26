# frozen_string_literal: true

require "test_helper"
require "socket"

class DeliverPushNotificationJobTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.organization = @organization

    @property = create_property(@organization, "DeliverJob Property")
    @unit = create_unit(@property, "DPJ-101")

    @resident_user = create_user_for_organization(
      organization: @organization,
      email: "dpj-resident@example.test",
      role: AvailableRoles::CLIENT
    )
    @resident_person = @resident_user.person_for(@organization)
    UnitOccupancy.create!(
      organization: @organization,
      person: @resident_person,
      unit: @unit,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: 1.day.ago,
      status: OccupancyStatuses::ACTIVE,
      can_authorize_visits: true
    )

    @visitor = Person.create!(
      organization: @organization,
      display_name: "DPJ Visitor",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @visit = Visit.create!(
      organization: @organization,
      unit: @unit,
      visitor_person: @visitor,
      scheduled_at: 1.hour.from_now,
      valid_from: 1.hour.ago,
      status: VisitStatuses::PENDING,
      visit_type: VisitTypes::GUEST
    )
    @notification = Notification.create!(
      organization: @organization,
      recipient_person: @resident_person,
      unit: @unit,
      residential_property: @property,
      notifiable: @visit,
      notification_type: NotificationTypes::VISIT_REQUEST,
      channel: NotificationChannels::PUSH,
      status: NotificationStatuses::PENDING
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "Sidekiq automatic retry is disabled" do
    assert_equal false, DeliverPushNotificationJob.sidekiq_options_hash["retry"]
  end

  test "no device token: notification is skipped, not left pending, no error" do
    DeliverPushNotificationJob.perform_now(@notification.id)

    @notification.reload
    assert_equal NotificationStatuses::SKIPPED, @notification.status
    assert_nil @notification.last_error
    assert_equal Visit::NotificationStatuses::NO_RECIPIENTS, @visit.reload.notification_status
  end

  test "successful delivery marks notification sent and visit delivered" do
    DeviceToken.create!(user: @resident_user, token: "tok-1", platform: "ios")

    with_fake_fcm_server(status_line: "200 OK", body: "{}") do
      DeliverPushNotificationJob.perform_now(@notification.id)
    end

    @notification.reload
    assert_equal NotificationStatuses::SENT, @notification.status
    assert_not_nil @notification.sent_at
    assert_nil @notification.last_error
    assert_equal 1, @notification.attempts_count
    assert_equal Visit::NotificationStatuses::DELIVERED, @visit.reload.notification_status
  end

  test "failed delivery marks notification failed and visit failed, without raising" do
    DeviceToken.create!(user: @resident_user, token: "tok-1", platform: "ios")

    with_fake_fcm_server(status_line: "500 Internal Server Error", body: "boom") do
      DeliverPushNotificationJob.perform_now(@notification.id)
    end

    @notification.reload
    assert_equal NotificationStatuses::FAILED, @notification.status
    assert_match(/500/, @notification.last_error)
    assert_equal 1, @notification.attempts_count
    assert_equal Visit::NotificationStatuses::FAILED, @visit.reload.notification_status
  end

  test "at least one success is enough for the visit to be marked delivered" do
    other_resident_user = create_user_for_organization(
      organization: @organization,
      email: "dpj-other-resident@example.test",
      role: AvailableRoles::CLIENT
    )
    other_resident_person = other_resident_user.person_for(@organization)
    UnitOccupancy.create!(
      organization: @organization,
      person: other_resident_person,
      unit: @unit,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: 1.day.ago,
      status: OccupancyStatuses::ACTIVE,
      can_authorize_visits: true
    )
    other_notification = Notification.create!(
      organization: @organization,
      recipient_person: other_resident_person,
      unit: @unit,
      residential_property: @property,
      notifiable: @visit,
      notification_type: NotificationTypes::VISIT_REQUEST,
      channel: NotificationChannels::PUSH,
      status: NotificationStatuses::PENDING
    )
    DeviceToken.create!(user: other_resident_user, token: "tok-2", platform: "android")
    # @resident_person has no token: contributes a "skipped" sibling, not a failure.

    with_fake_fcm_server(status_line: "200 OK", body: "{}") do
      DeliverPushNotificationJob.perform_now(other_notification.id)
      DeliverPushNotificationJob.perform_now(@notification.id)
    end

    assert_equal Visit::NotificationStatuses::DELIVERED, @visit.reload.notification_status
  end

  test "a user's single device token receives deliveries for visits in any organization they authorize in" do
    other_organization = organizations(:two)
    other_property = other_scoped { create_property(other_organization, "DeliverJob Other Org Property") }
    other_unit = other_scoped { create_unit(other_property, "DPJ-OTHER-101") }
    other_person = other_scoped do
      Person.create!(
        organization: other_organization,
        user: @resident_user,
        display_name: @resident_user.name,
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
    end
    other_visitor = other_scoped do
      Person.create!(
        organization: other_organization,
        display_name: "DPJ Other Org Visitor",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
    end
    other_scoped do
      UnitOccupancy.create!(
        organization: other_organization,
        person: other_person,
        unit: other_unit,
        occupancy_type: OccupancyTypes::TENANT,
        starts_at: 1.day.ago,
        status: OccupancyStatuses::ACTIVE,
        can_authorize_visits: true
      )
    end
    other_visit = other_scoped do
      Visit.create!(
        organization: other_organization,
        unit: other_unit,
        visitor_person: other_visitor,
        scheduled_at: 1.hour.from_now,
        valid_from: 1.hour.ago,
        status: VisitStatuses::PENDING,
        visit_type: VisitTypes::GUEST
      )
    end
    other_notification = other_scoped do
      Notification.create!(
        organization: other_organization,
        recipient_person: other_person,
        unit: other_unit,
        residential_property: other_property,
        notifiable: other_visit,
        notification_type: NotificationTypes::VISIT_REQUEST,
        channel: NotificationChannels::PUSH,
        status: NotificationStatuses::PENDING
      )
    end

    DeviceToken.create!(user: @resident_user, token: "shared-device-token", platform: "ios")

    with_fake_fcm_server(status_line: "200 OK", body: "{}") do
      DeliverPushNotificationJob.perform_now(@notification.id)
    end
    assert_equal NotificationStatuses::SENT, @notification.reload.status

    with_fake_fcm_server(status_line: "200 OK", body: "{}") do
      DeliverPushNotificationJob.perform_now(other_notification.id)
    end
    assert_equal NotificationStatuses::SENT, other_notification.reload.status
  end

  private

  def other_scoped
    ActsAsTenant.with_tenant(organizations(:two)) { yield }
  end

  def with_fake_fcm_server(status_line:, body:)
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]

    thread = Thread.new do
      connection = server.accept
      connection.gets
      while (line = connection.gets) && line != "\r\n"; end
      connection.write("HTTP/1.1 #{status_line}\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
      connection.close
    end

    original_base_url = ENV["FCM_BASE_URL"]
    ENV["FCM_BASE_URL"] = "http://127.0.0.1:#{port}"
    yield
    thread.join(2)
  ensure
    ENV["FCM_BASE_URL"] = original_base_url
    server&.close
  end
end
