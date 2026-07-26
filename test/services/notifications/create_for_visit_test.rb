# frozen_string_literal: true

require "test_helper"

module Notifications
  class CreateForVisitTest < ActiveSupport::TestCase
    include OperationalPolicyTestHelper
    include ActiveJob::TestHelper

    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization
      Current.organization = @organization

      @property = create_property(@organization, "CreateForVisit Property")
      @unit = create_unit(@property, "CFV-101")
      @other_unit = create_unit(@property, "CFV-102")

      @authorizer_user = create_user_for_organization(
        organization: @organization,
        email: "cfv-authorizer@example.test",
        role: AvailableRoles::CLIENT
      )
      @authorizer_person = @authorizer_user.person_for(@organization)
      UnitOccupancy.create!(
        organization: @organization,
        person: @authorizer_person,
        unit: @unit,
        occupancy_type: OccupancyTypes::TENANT,
        starts_at: 1.day.ago,
        status: OccupancyStatuses::ACTIVE,
        can_authorize_visits: true
      )

      @other_unit_authorizer = create_user_for_organization(
        organization: @organization,
        email: "cfv-other-unit-authorizer@example.test",
        role: AvailableRoles::CLIENT
      )
      UnitOccupancy.create!(
        organization: @organization,
        person: @other_unit_authorizer.person_for(@organization),
        unit: @other_unit,
        occupancy_type: OccupancyTypes::TENANT,
        starts_at: 1.day.ago,
        status: OccupancyStatuses::ACTIVE,
        can_authorize_visits: true
      )

      @visitor = Person.create!(
        organization: @organization,
        display_name: "CFV Visitor",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
      Current.reset
    end

    def build_visit(unit)
      Visit.create!(
        organization: @organization,
        unit: unit,
        visitor_person: @visitor,
        scheduled_at: 1.hour.from_now,
        valid_from: 1.hour.ago,
        status: VisitStatuses::PENDING,
        visit_type: VisitTypes::GUEST
      )
    end

    test "creates one Notification for each active authorizer of the visited unit only" do
      visit = build_visit(@unit)

      assert_enqueued_jobs 1, only: DeliverPushNotificationJob do
        CreateForVisit.call(visit: visit)
      end

      notifications = visit.notifications.where(notification_type: NotificationTypes::VISIT_REQUEST)
      assert_equal 1, notifications.count
      assert_equal @authorizer_person.id, notifications.first.recipient_person_id
      assert_equal NotificationChannels::PUSH, notifications.first.channel
      assert_equal NotificationStatuses::PENDING, notifications.first.status
    end

    test "does not notify authorizers of other units in the same property" do
      visit = build_visit(@unit)

      CreateForVisit.call(visit: visit)

      recipient_ids = visit.notifications.pluck(:recipient_person_id)
      refute_includes recipient_ids, @other_unit_authorizer.person_for(@organization).id
    end

    test "sets notification_status to no_recipients when the unit has no active authorizer" do
      empty_unit = create_unit(@property, "CFV-103")
      # A resident with can_authorize_visits: false is not a notification
      # recipient, so this unit genuinely has zero authorizers.
      non_authorizing_resident = create_user_for_organization(
        organization: @organization,
        email: "cfv-non-authorizing@example.test",
        role: AvailableRoles::CLIENT
      ).person_for(@organization)
      UnitOccupancy.create!(
        organization: @organization,
        person: non_authorizing_resident,
        unit: empty_unit,
        occupancy_type: OccupancyTypes::TENANT,
        starts_at: 1.day.ago,
        status: OccupancyStatuses::ACTIVE,
        can_authorize_visits: false
      )
      visit = build_visit(empty_unit)

      assert_no_enqueued_jobs only: DeliverPushNotificationJob do
        CreateForVisit.call(visit: visit)
      end

      assert_equal Visit::NotificationStatuses::NO_RECIPIENTS, visit.reload.notification_status
      assert_empty visit.notifications
    end
  end
end
