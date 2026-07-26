# frozen_string_literal: true

require "test_helper"

module Visits
  class ResendNotificationTest < ActiveSupport::TestCase
    include OperationalPolicyTestHelper
    include ActiveJob::TestHelper

    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization
      Current.organization = @organization

      @property = create_property(@organization, "Resend Property")
      @unit = create_unit(@property, "RESEND-101")

      @resident_user = create_user_for_organization(
        organization: @organization,
        email: "resend-resident@example.test",
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

      @admin = create_user_for_organization(
        organization: @organization,
        email: "resend-admin@example.test",
        role: AvailableRoles::TENANT_ADMIN
      )

      @visitor = Person.create!(
        organization: @organization,
        display_name: "Resend Visitor",
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
        visit_type: VisitTypes::GUEST,
        notification_status: Visit::NotificationStatuses::FAILED
      )
      @notification = Notification.create!(
        organization: @organization,
        recipient_person: @resident_person,
        unit: @unit,
        residential_property: @property,
        notifiable: @visit,
        notification_type: NotificationTypes::VISIT_REQUEST,
        channel: NotificationChannels::PUSH,
        status: NotificationStatuses::FAILED,
        last_error: "boom",
        attempts_count: 1
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
      Current.reset
    end

    test "resends to the original recipient and resets statuses to pending" do
      assert_enqueued_jobs 1, only: DeliverPushNotificationJob do
        ResendNotification.call(visit: @visit, actor: @admin)
      end

      assert_equal Visit::NotificationStatuses::PENDING, @visit.reload.notification_status
      @notification.reload
      assert_equal NotificationStatuses::PENDING, @notification.status
      assert_nil @notification.last_error
    end

    test "audit history preserves the original failed attempt after a resend changes the row" do
      ResendNotification.call(visit: @visit, actor: @admin)
      @notification.reload
      @notification.update!(status: NotificationStatuses::FAILED, last_error: "boom again", attempts_count: 2)

      audited_statuses = @notification.audits.map { |audit| audit.audited_changes["status"] }.compact.flatten
      audited_errors = @notification.audits.map { |audit| audit.audited_changes["last_error"] }.compact.flatten

      assert_includes audited_statuses, "failed"
      assert_includes audited_errors, "boom"
      assert_equal NotificationStatuses::FAILED, @notification.status
      assert_equal "boom again", @notification.last_error
    end

    test "raises when notification_status is not failed" do
      @visit.update!(notification_status: Visit::NotificationStatuses::DELIVERED)

      assert_raises(ResendNotification::NotFailedError) do
        ResendNotification.call(visit: @visit, actor: @admin)
      end
    end

    test "a resident cannot resend (admin-only action)" do
      assert_raises(Pundit::NotAuthorizedError) do
        ResendNotification.call(visit: @visit, actor: @resident_user)
      end
    end

    test "targets the original recipient even if unit occupancy changed since" do
      @resident_person_occupancy = UnitOccupancy.find_by(person: @resident_person, unit: @unit)
      @resident_person_occupancy.update!(can_authorize_visits: false)

      new_resident = create_user_for_organization(
        organization: @organization,
        email: "resend-new-resident@example.test",
        role: AvailableRoles::CLIENT
      )
      UnitOccupancy.create!(
        organization: @organization,
        person: new_resident.person_for(@organization),
        unit: @unit,
        occupancy_type: OccupancyTypes::TENANT,
        starts_at: 1.day.ago,
        status: OccupancyStatuses::ACTIVE,
        can_authorize_visits: true
      )

      ResendNotification.call(visit: @visit, actor: @admin)

      recipient_ids = @visit.reload.notifications.pluck(:recipient_person_id)
      assert_equal [ @resident_person.id ], recipient_ids
    end
  end
end
