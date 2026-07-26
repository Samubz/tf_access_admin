# frozen_string_literal: true

require "test_helper"

class Visit::StateMachineTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @property = create_property(@organization, "Visit State Machine Property")
    @unit = create_unit(@property, "VISIT-SM-101")
    @host = Person.create!(
      organization: @organization,
      display_name: "State Machine Host",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @visitor = Person.create!(
      organization: @organization,
      display_name: "State Machine Visitor",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    UnitOwnership.create!(
      organization: @organization,
      person: @host,
      unit: @unit,
      ownership_percentage: 100,
      starts_at: Date.current,
      status: UnitOwnership::STATUS_ACTIVE
    )

    @actor = create_user_for_organization(
      organization: @organization,
      email: "visit-state-machine-actor@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "authorize transitions pending to authorized and records actor" do
    visit = create_visit!(status: VisitStatuses::PENDING)

    visit.authorize!(@actor)

    assert_equal VisitStatuses::AUTHORIZED, visit.status
    assert_equal @actor.id, visit.authorized_by_id
    assert_not_nil visit.authorized_at
  end

  test "check_in transitions authorized to checked_in and records actor" do
    visit = create_visit!(
      status: VisitStatuses::AUTHORIZED,
      valid_from: 1.hour.ago,
      valid_until: 1.hour.from_now
    )

    visit.check_in!(@actor)

    assert_equal VisitStatuses::CHECKED_IN, visit.status
    assert_equal @actor.id, visit.checked_in_by_id
    assert_not_nil visit.checked_in_at
  end

  test "check_out transitions checked_in to checked_out and records actor" do
    visit = create_visit!(
      status: VisitStatuses::CHECKED_IN,
      checked_in_by: @actor,
      checked_in_at: 30.minutes.ago
    )

    visit.check_out!(@actor)

    assert_equal VisitStatuses::CHECKED_OUT, visit.status
    assert_equal @actor.id, visit.checked_out_by_id
    assert_not_nil visit.checked_out_at
  end

  test "cancel transitions pending to cancelled" do
    visit = create_visit!(status: VisitStatuses::PENDING)

    visit.cancel!

    assert_equal VisitStatuses::CANCELLED, visit.status
  end

  test "cancel transitions authorized to cancelled" do
    visit = create_visit!(status: VisitStatuses::AUTHORIZED, authorized_by: @actor, authorized_at: Time.zone.now)

    visit.cancel!

    assert_equal VisitStatuses::CANCELLED, visit.status
  end

  test "pending visit cannot check in" do
    visit = create_visit!(status: VisitStatuses::PENDING)

    assert_raises(AASM::InvalidTransition) { visit.check_in!(@actor) }
    assert_equal VisitStatuses::PENDING, visit.reload.status
    assert_nil visit.checked_in_by_id
  end

  test "authorized visit cannot check out directly" do
    visit = create_visit!(status: VisitStatuses::AUTHORIZED, authorized_by: @actor, authorized_at: Time.zone.now)

    assert_raises(AASM::InvalidTransition) { visit.check_out!(@actor) }
    assert_equal VisitStatuses::AUTHORIZED, visit.reload.status
    assert_nil visit.checked_out_by_id
  end

  test "checked_in visit cannot be cancelled" do
    visit = create_visit!(
      status: VisitStatuses::CHECKED_IN,
      checked_in_by: @actor,
      checked_in_at: Time.zone.now
    )

    assert_raises(AASM::InvalidTransition) { visit.cancel! }
    assert_equal VisitStatuses::CHECKED_IN, visit.reload.status
  end

  test "checked_out visit cannot be cancelled" do
    visit = create_visit!(
      status: VisitStatuses::CHECKED_OUT,
      checked_in_by: @actor,
      checked_in_at: 1.hour.ago,
      checked_out_by: @actor,
      checked_out_at: Time.zone.now
    )

    assert_raises(AASM::InvalidTransition) { visit.cancel! }
    assert_equal VisitStatuses::CHECKED_OUT, visit.reload.status
  end

  test "check_in is rejected outside validity window" do
    visit = create_visit!(
      status: VisitStatuses::AUTHORIZED,
      authorized_by: @actor,
      authorized_at: Time.zone.now,
      valid_from: 2.days.from_now,
      valid_until: 3.days.from_now
    )

    assert_raises(AASM::InvalidTransition) { visit.check_in!(@actor) }
    assert_equal VisitStatuses::AUTHORIZED, visit.reload.status
    assert_nil visit.checked_in_by_id
  end

  test "status transitions generate audited records" do
    visit = create_visit!(status: VisitStatuses::PENDING)

    assert_difference -> { Audited::Audit.where(auditable_type: "Visit", auditable_id: visit.id).count }, 1 do
      visit.authorize!(@actor)
    end
  end

  private

  def create_visit!(**overrides)
    defaults = {
      organization: @organization,
      unit: @unit,
      visitor_person: @visitor,
      scheduled_at: 1.day.from_now,
      valid_from: 1.day.from_now,
      visit_type: VisitTypes::GUEST
    }

    Visit.create!(defaults.merge(overrides))
  end
end
