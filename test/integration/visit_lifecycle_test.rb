# frozen_string_literal: true

require "test_helper"

# §14.3, §14.4, §14.5 — End-to-end service-layer integration tests for the
# visit lifecycle. These tests go through the Visits::* service objects
# (the same path the controllers invoke) so they exercise authorization,
# state transitions, event recording, and scope/visibility together.
class VisitLifecycleTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization

    @property = create_property(@organization, "Lifecycle Property P")
    @other_property = create_property(@organization, "Lifecycle Property Q")
    @unit = create_unit(@property, "LC-P-101")

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "lifecycle-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @property_admin = create_staff_user(
      organization: @organization,
      email: "lifecycle-prop-admin@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )
    @concierge = create_staff_user(
      organization: @organization,
      email: "lifecycle-concierge@example.test",
      staff_type: StaffTypes::CONCIERGE,
      property: @property
    )
    @concierge_q = create_staff_user(
      organization: @organization,
      email: "lifecycle-concierge-q@example.test",
      staff_type: StaffTypes::CONCIERGE,
      property: @other_property
    )
    @owner = create_owner_user(
      organization: @organization,
      email: "lifecycle-owner@example.test",
      unit: @unit
    )

    @visitor_person = Person.create!(
      organization: @organization,
      display_name: "Lifecycle Visitor",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  # ─── §14.3 Full lifecycle: pending → authorized → checked_in → checked_out ──

  test "tenant_admin can complete the full visit lifecycle" do
    Current.user = @tenant_admin

    # 1. Create → pending (tenant_admin lacks direct-authorize in this context)
    visit = Visits::Create.call(
      unit: @unit,
      visit_params: {
        visitor_person_id: @visitor_person.id,
        scheduled_at: 2.hours.from_now,
        valid_from: 1.hour.ago,
        visit_type: VisitTypes::GUEST
      },
      actor: @tenant_admin
    )
    assert visit.persisted?
    # tenant_admin can authorize directly, so it may be authorized immediately
    assert_includes [ VisitStatuses::PENDING, VisitStatuses::AUTHORIZED ], visit.status

    # 2. Authorize → authorized
    if visit.status == VisitStatuses::PENDING
      visit = Visits::Authorize.call(visit: visit, actor: @tenant_admin)
    end
    assert_equal VisitStatuses::AUTHORIZED, visit.status
    assert_not_nil visit.authorized_at
    assert_equal @tenant_admin.id, visit.authorized_by_id

    # 3. Check-in → checked_in (tenant_admin has manage_visits but not register_visit_entry
    #    unless org-level capability grants it; concierge holds register_visit_entry)
    visit = Visits::CheckIn.call(
      visit: visit,
      actor: @concierge,
      access_point: "main_entrance"
    )
    assert_equal VisitStatuses::CHECKED_IN, visit.status
    assert_not_nil visit.checked_in_at
    assert_equal @concierge.id, visit.checked_in_by_id

    # 4. Check-out → checked_out
    visit = Visits::CheckOut.call(
      visit: visit,
      actor: @concierge
    )
    assert_equal VisitStatuses::CHECKED_OUT, visit.status
    assert_not_nil visit.checked_out_at
    assert_equal @concierge.id, visit.checked_out_by_id
  end

  test "full lifecycle records a functional event for each transition (§14.3)" do
    Current.user = @tenant_admin

    visit = ActsAsTenant.with_tenant(@organization) do
      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: @visitor_person,
        scheduled_at: 2.hours.from_now,
        valid_from: 1.hour.ago,
        status: VisitStatuses::PENDING,
        visit_type: VisitTypes::GUEST
      )
    end

    Visits::Authorize.call(visit: visit, actor: @tenant_admin)
    Visits::CheckIn.call(visit: visit, actor: @concierge)
    Visits::CheckOut.call(visit: visit, actor: @concierge)

    visit.reload
    history = visit.visit_status_histories.order(:occurred_at)
    event_types = history.pluck(:event_type)

    assert_includes event_types, VisitEventTypes::AUTHORIZED
    assert_includes event_types, VisitEventTypes::CHECKED_IN
    assert_includes event_types, VisitEventTypes::CHECKED_OUT
    assert_equal VisitStatuses::CHECKED_OUT, history.last.to_status
  end

  # ─── §14.4 Cancellation allowed/denied + functional history ─────────────────

  test "tenant_admin can cancel a pending visit and history records the event" do
    Current.user = @tenant_admin

    visit = ActsAsTenant.with_tenant(@organization) do
      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: @visitor_person,
        scheduled_at: 2.days.from_now,
        valid_from: 2.days.from_now,
        status: VisitStatuses::PENDING,
        visit_type: VisitTypes::GUEST
      )
    end

    Visits::Cancel.call(visit: visit, actor: @tenant_admin, notes: "Cancelled by admin")
    visit.reload

    assert_equal VisitStatuses::CANCELLED, visit.status

    cancel_event = visit.visit_status_histories.find_by(event_type: VisitEventTypes::CANCELLED)
    assert_not_nil cancel_event
    assert_equal VisitStatuses::PENDING, cancel_event.from_status
    assert_equal VisitStatuses::CANCELLED, cancel_event.to_status
    assert_equal "Cancelled by admin", cancel_event.notes
  end

  test "tenant_admin can cancel an authorized visit (§14.4)" do
    Current.user = @tenant_admin

    visit = ActsAsTenant.with_tenant(@organization) do
      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: @visitor_person,
        scheduled_at: 2.days.from_now,
        valid_from: 2.days.from_now,
        status: VisitStatuses::AUTHORIZED,
        authorized_at: 10.minutes.ago,
        authorized_by_id: @tenant_admin.id,
        visit_type: VisitTypes::GUEST
      )
    end

    Visits::Cancel.call(visit: visit, actor: @tenant_admin)
    assert_equal VisitStatuses::CANCELLED, visit.reload.status
  end

  test "cancel is denied for checked_in visit (policy blocks before AASM, §14.4)" do
    Current.user = @tenant_admin

    visit = ActsAsTenant.with_tenant(@organization) do
      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: @visitor_person,
        scheduled_at: 2.hours.from_now,
        valid_from: 1.hour.ago,
        status: VisitStatuses::CHECKED_IN,
        authorized_at: 30.minutes.ago,
        authorized_by_id: @tenant_admin.id,
        checked_in_at: 20.minutes.ago,
        checked_in_by_id: @concierge.id,
        visit_type: VisitTypes::GUEST
      )
    end

    assert_raises(Pundit::NotAuthorizedError) do
      Visits::Cancel.call(visit: visit, actor: @tenant_admin)
    end
    assert_equal VisitStatuses::CHECKED_IN, visit.reload.status
  end

  test "cancel is denied for checked_out visit (policy blocks before AASM, §14.4)" do
    Current.user = @tenant_admin

    visit = ActsAsTenant.with_tenant(@organization) do
      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: @visitor_person,
        scheduled_at: 3.hours.ago,
        valid_from: 3.hours.ago,
        status: VisitStatuses::CHECKED_OUT,
        authorized_at: 2.hours.ago,
        authorized_by_id: @tenant_admin.id,
        checked_in_at: 1.hour.ago,
        checked_in_by_id: @concierge.id,
        checked_out_at: 30.minutes.ago,
        checked_out_by_id: @concierge.id,
        visit_type: VisitTypes::GUEST
      )
    end

    assert_raises(Pundit::NotAuthorizedError) do
      Visits::Cancel.call(visit: visit, actor: @tenant_admin)
    end
  end

  test "concierge cannot cancel a visit (Pundit::NotAuthorizedError, §14.4)" do
    Current.user = @concierge

    visit = ActsAsTenant.with_tenant(@organization) do
      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: @visitor_person,
        scheduled_at: 2.days.from_now,
        valid_from: 2.days.from_now,
        status: VisitStatuses::AUTHORIZED,
        authorized_at: 10.minutes.ago,
        authorized_by_id: @tenant_admin.id,
        visit_type: VisitTypes::GUEST
      )
    end

    assert_raises(Pundit::NotAuthorizedError) do
      Visits::Cancel.call(visit: visit, actor: @concierge)
    end
    assert_equal VisitStatuses::AUTHORIZED, visit.reload.status
  end

  # ─── §14.5 Concierge constraints ────────────────────────────────────────────

  test "concierge cannot create a visit (Pundit::NotAuthorizedError, §14.5)" do
    Current.user = @concierge

    assert_raises(Pundit::NotAuthorizedError) do
      Visits::Create.call(
        unit: @unit,
        visit_params: {
          visitor_person_id: @visitor_person.id,
          scheduled_at: 2.hours.from_now,
          valid_from: 1.hour.ago,
          visit_type: VisitTypes::GUEST
        },
        actor: @concierge
      )
    end
  end

  test "concierge cannot authorize a visit (Pundit::NotAuthorizedError, §14.5)" do
    Current.user = @concierge

    visit = ActsAsTenant.with_tenant(@organization) do
      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: @visitor_person,
        scheduled_at: 2.days.from_now,
        valid_from: 2.days.from_now,
        status: VisitStatuses::PENDING,
        visit_type: VisitTypes::GUEST
      )
    end

    assert_raises(Pundit::NotAuthorizedError) do
      Visits::Authorize.call(visit: visit, actor: @concierge)
    end
    assert_equal VisitStatuses::PENDING, visit.reload.status
  end

  test "concierge can check in an authorized visit on their property (§14.5)" do
    Current.user = @concierge

    visit = ActsAsTenant.with_tenant(@organization) do
      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: @visitor_person,
        scheduled_at: 2.hours.from_now,
        valid_from: 1.hour.ago,
        status: VisitStatuses::AUTHORIZED,
        authorized_at: 10.minutes.ago,
        authorized_by_id: @tenant_admin.id,
        visit_type: VisitTypes::GUEST
      )
    end

    visit = Visits::CheckIn.call(visit: visit, actor: @concierge, access_point: "main_entrance")
    assert_equal VisitStatuses::CHECKED_IN, visit.status
  end

  test "concierge from other property cannot check in (Pundit::NotAuthorizedError, §14.5)" do
    Current.user = @concierge_q

    visit = ActsAsTenant.with_tenant(@organization) do
      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: @visitor_person,
        scheduled_at: 2.hours.from_now,
        valid_from: 1.hour.ago,
        status: VisitStatuses::AUTHORIZED,
        authorized_at: 10.minutes.ago,
        authorized_by_id: @tenant_admin.id,
        visit_type: VisitTypes::GUEST
      )
    end

    assert_raises(Pundit::NotAuthorizedError) do
      Visits::CheckIn.call(visit: visit, actor: @concierge_q)
    end
    assert_equal VisitStatuses::AUTHORIZED, visit.reload.status
  end

  test "concierge can check out a checked_in visit on their property (§14.5)" do
    Current.user = @concierge

    visit = ActsAsTenant.with_tenant(@organization) do
      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: @visitor_person,
        scheduled_at: 3.hours.ago,
        valid_from: 3.hours.ago,
        status: VisitStatuses::CHECKED_IN,
        authorized_at: 2.hours.ago,
        authorized_by_id: @tenant_admin.id,
        checked_in_at: 1.hour.ago,
        checked_in_by_id: @concierge.id,
        visit_type: VisitTypes::GUEST
      )
    end

    visit = Visits::CheckOut.call(visit: visit, actor: @concierge)
    assert_equal VisitStatuses::CHECKED_OUT, visit.status
  end

  test "check_in is denied for pending visit (AASM::InvalidTransition, §14.5)" do
    Current.user = @concierge

    visit = ActsAsTenant.with_tenant(@organization) do
      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: @visitor_person,
        scheduled_at: 2.hours.from_now,
        valid_from: 1.hour.from_now,
        status: VisitStatuses::PENDING,
        visit_type: VisitTypes::GUEST
      )
    end

    assert_raises(AASM::InvalidTransition) do
      Visits::CheckIn.call(visit: visit, actor: @concierge)
    end
  end
end
