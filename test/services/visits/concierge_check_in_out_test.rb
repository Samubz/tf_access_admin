# frozen_string_literal: true

require "test_helper"

module Visits
  # State, actor, concurrency and isolation tests for concierge check-in/check-out
  # (OpenSpec concierge-visit-access-flow §8.2, §8.6–§8.10, §8.13).
  class ConciergeCheckInOutTest < ActiveSupport::TestCase
    include OperationalPolicyTestHelper

    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization
      Current.organization = @organization

      @property = create_property(@organization, "CheckInOut Property")
      @unit = create_unit(@property, "CIO-101")
      @host = Person.create!(
        organization: @organization, display_name: "CIO Host",
        person_type: PersonTypes::NATURAL, status: PersonStatuses::ACTIVE
      )
      UnitOwnership.create!(
        organization: @organization, person: @host, unit: @unit,
        ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
      )
      @tenant_admin = create_user_for_organization(
        organization: @organization, email: "cio-admin@example.test", role: AvailableRoles::TENANT_ADMIN
      )
      @concierge = create_staff_user(
        organization: @organization, email: "cio-concierge@example.test",
        staff_type: StaffTypes::CONCIERGE, property: @property
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
      Current.reset
    end

    # ─── 8.6 check-in success + User actor ────────────────────────────────────

    test "check-in transitions to checked_in and records the User actor" do
      visit = authorized_visit!

      CheckIn.call(visit: visit, actor: @concierge, access_point: "main_entrance")

      visit.reload
      assert_equal VisitStatuses::CHECKED_IN, visit.status
      assert_equal @concierge.id, visit.checked_in_by_id
      assert_kind_of User, visit.checked_in_by
      assert_not_nil visit.checked_in_at
    end

    # ─── 8.7 reject invalid states at check-in ────────────────────────────────

    test "check-in rejects a cancelled visit" do
      visit = build_visit!(status: VisitStatuses::CANCELLED)
      assert_raises(AASM::InvalidTransition) { CheckIn.call(visit: visit, actor: @concierge) }
      assert_equal VisitStatuses::CANCELLED, visit.reload.status
    end

    test "check-in rejects an expired visit" do
      visit = build_visit!(status: VisitStatuses::EXPIRED)
      assert_raises(AASM::InvalidTransition) { CheckIn.call(visit: visit, actor: @concierge) }
      assert_equal VisitStatuses::EXPIRED, visit.reload.status
    end

    test "check-in rejects an authorized visit whose validity window has lapsed" do
      visit = build_visit!(
        status: VisitStatuses::AUTHORIZED,
        scheduled_at: 3.hours.ago, valid_from: 3.hours.ago, valid_until: 1.hour.ago
      )
      assert_raises(AASM::InvalidTransition) { CheckIn.call(visit: visit, actor: @concierge) }
      assert_equal VisitStatuses::AUTHORIZED, visit.reload.status
    end

    test "check-in rejects a pending visit" do
      visit = build_visit!(status: VisitStatuses::PENDING, scheduled_at: 2.days.from_now)
      assert_raises(AASM::InvalidTransition) { CheckIn.call(visit: visit, actor: @concierge) }
      assert_equal VisitStatuses::PENDING, visit.reload.status
    end

    # ─── 8.8 double check-in (sequential + concurrent simulation) ─────────────

    test "second sequential check-in is rejected" do
      visit = authorized_visit!
      CheckIn.call(visit: visit, actor: @concierge)
      assert_raises(AASM::InvalidTransition) { CheckIn.call(visit: visit, actor: @concierge) }
      assert_equal VisitStatuses::CHECKED_IN, visit.reload.status
    end

    test "concurrent check-in on a stale instance is serialized by the row lock" do
      visit = authorized_visit!
      stale = Visit.find(visit.id) # second request loaded while still authorized

      CheckIn.call(visit: visit, actor: @concierge)

      # with_lock reloads the stale copy to the committed state before transitioning.
      assert_raises(AASM::InvalidTransition) { CheckIn.call(visit: stale, actor: @concierge) }
      assert_equal 1, visit.visit_status_histories.where(event_type: VisitEventTypes::CHECKED_IN).count
    end

    # ─── 8.9 check-out success + User actor ───────────────────────────────────

    test "check-out transitions to checked_out and records the User actor" do
      visit = checked_in_visit!

      CheckOut.call(visit: visit, actor: @concierge, access_point: "main_entrance")

      visit.reload
      assert_equal VisitStatuses::CHECKED_OUT, visit.status
      assert_equal @concierge.id, visit.checked_out_by_id
      assert_kind_of User, visit.checked_out_by
      assert_not_nil visit.checked_out_at
    end

    # ─── 8.10 check-out from invalid state + duplicate exit ───────────────────

    test "check-out is rejected from authorized state" do
      visit = authorized_visit!
      assert_raises(AASM::InvalidTransition) { CheckOut.call(visit: visit, actor: @concierge) }
      assert_equal VisitStatuses::AUTHORIZED, visit.reload.status
    end

    test "second check-out is rejected" do
      visit = checked_in_visit!
      CheckOut.call(visit: visit, actor: @concierge)
      assert_raises(AASM::InvalidTransition) { CheckOut.call(visit: visit, actor: @concierge) }
      assert_equal VisitStatuses::CHECKED_OUT, visit.reload.status
    end

    # ─── 8.2 assignment state gating ──────────────────────────────────────────

    test "concierge with inactive assignment cannot check in" do
      deactivate_assignment!(status: "inactive")
      visit = authorized_visit!
      assert_raises(Pundit::NotAuthorizedError) { CheckIn.call(visit: visit, actor: @concierge) }
      assert_equal VisitStatuses::AUTHORIZED, visit.reload.status
    end

    test "concierge with future-dated assignment cannot check in" do
      deactivate_assignment!(starts_at: 3.days.from_now)
      visit = authorized_visit!
      assert_raises(Pundit::NotAuthorizedError) { CheckIn.call(visit: visit, actor: @concierge) }
      assert_equal VisitStatuses::AUTHORIZED, visit.reload.status
    end

    test "concierge with expired assignment cannot check in" do
      deactivate_assignment!(starts_at: 10.days.ago, ends_at: 1.day.ago)
      visit = authorized_visit!
      assert_raises(Pundit::NotAuthorizedError) { CheckIn.call(visit: visit, actor: @concierge) }
      assert_equal VisitStatuses::AUTHORIZED, visit.reload.status
    end

    # ─── 8.13 atomic rollback between visit and history ───────────────────────

    test "check-in rolls back the transition when history recording fails" do
      visit = authorized_visit!
      original_call = RecordEvent.method(:call)
      RecordEvent.define_singleton_method(:call) do |**_kwargs|
        invalid = VisitStatusHistory.new
        invalid.errors.add(:event_type, "forced failure")
        raise ActiveRecord::RecordInvalid.new(invalid)
      end

      assert_raises(ActiveRecord::RecordInvalid) { CheckIn.call(visit: visit, actor: @concierge) }

      visit.reload
      assert_equal VisitStatuses::AUTHORIZED, visit.status
      assert_nil visit.checked_in_at
      assert_equal 0, visit.visit_status_histories.where(event_type: VisitEventTypes::CHECKED_IN).count
    ensure
      RecordEvent.define_singleton_method(:call, original_call)
    end

    private

    def deactivate_assignment!(**attrs)
      StaffAssignment.where(person: @concierge.person_for(@organization)).update_all(attrs)
    end

    def build_visit!(status:, scheduled_at: 1.hour.from_now, valid_from: nil, valid_until: nil)
      ActsAsTenant.with_tenant(@organization) do
        visitor = Person.create!(
          organization: @organization, display_name: "Visitor #{SecureRandom.hex(4)}",
          person_type: PersonTypes::NATURAL, status: PersonStatuses::ACTIVE
        )
        Visit.create!(
          organization: @organization, unit: @unit, visitor_person: visitor,
          scheduled_at: scheduled_at, valid_from: valid_from || scheduled_at, valid_until: valid_until,
          status: status
        )
      end
    end

    def authorized_visit!
      build_visit!(
        status: VisitStatuses::AUTHORIZED,
        scheduled_at: 30.minutes.from_now, valid_from: 1.hour.ago, valid_until: 2.hours.from_now
      ).tap do |v|
        v.update_columns(authorized_at: 10.minutes.ago, authorized_by_id: @tenant_admin.id)
      end
    end

    def checked_in_visit!
      visit = authorized_visit!
      CheckIn.call(visit: visit, actor: @concierge)
      visit
    end
  end
end
