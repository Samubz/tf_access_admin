# frozen_string_literal: true

require "test_helper"

module Visits
  class FunctionalHistoryTest < ActiveSupport::TestCase
    include OperationalPolicyTestHelper

    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization

      @property = create_property(@organization, "Functional History Property")
      @unit = create_unit(@property, "FUNC-HIST-101")
      @host = Person.create!(
        organization: @organization,
        display_name: "Functional History Host",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      @visitor = Person.create!(
        organization: @organization,
        display_name: "Functional History Visitor",
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

      @tenant_admin = create_user_for_organization(
        organization: @organization,
        email: "functional-history-admin@example.test",
        role: AvailableRoles::TENANT_ADMIN
      )
      @concierge = create_staff_user(
        organization: @organization,
        email: "functional-history-concierge@example.test",
        staff_type: StaffTypes::CONCIERGE,
        property: @property
      )

      @visit_params = {
        visitor_person_id: @visitor.id,
        scheduled_at: 1.hour.from_now,
        valid_from: 1.hour.ago,
        valid_until: 2.hours.from_now,
        visit_type: VisitTypes::GUEST
      }
    end

    teardown do
      ActsAsTenant.current_tenant = nil
      Current.reset
    end

    test "create records created event with actor and resulting status" do
      visit = Create.call(
        unit: @unit,
        visit_params: @visit_params,
        actor: @tenant_admin,
        requested_status: VisitStatuses::AUTHORIZED
      )

      event = visit.visit_status_histories.sole

      assert_equal VisitEventTypes::CREATED, event.event_type
      assert_nil event.from_status
      assert_equal VisitStatuses::AUTHORIZED, event.to_status
      assert_equal @tenant_admin.id, event.actor_user_id
      assert_not_nil event.occurred_at
    end

    test "authorize records authorized event in same transaction" do
      visit = create_pending_visit!

      Authorize.call(visit: visit, actor: @tenant_admin, notes: "Approved")

      event = visit.visit_status_histories.order(:occurred_at).last

      assert_equal VisitEventTypes::AUTHORIZED, event.event_type
      assert_equal VisitStatuses::PENDING, event.from_status
      assert_equal VisitStatuses::AUTHORIZED, event.to_status
      assert_equal @tenant_admin.id, event.actor_user_id
      assert_equal "Approved", event.notes
    end

    test "check_in records checked_in event with operational metadata" do
      visit = create_authorized_visit!

      CheckIn.call(
        visit: visit,
        actor: @concierge,
        check_in_metadata: {
          access_point: "Main gate",
          access_type: VisitAccessTypes::PEDESTRIAN,
          notes: "On time"
        },
        notes: "Entry confirmed"
      )

      event = visit.visit_status_histories.order(:occurred_at).last

      assert_equal VisitEventTypes::CHECKED_IN, event.event_type
      assert_equal VisitStatuses::AUTHORIZED, event.from_status
      assert_equal VisitStatuses::CHECKED_IN, event.to_status
      assert_equal @concierge.id, event.actor_user_id
      assert_equal "Main gate", event.metadata.dig("check_in", "access_point")
      assert_equal VisitAccessTypes::PEDESTRIAN, event.metadata.dig("check_in", "access_type")
      assert_equal "Entry confirmed", event.notes
    end

    test "check_out records checked_out event with operational metadata" do
      visit = create_checked_in_visit!

      CheckOut.call(
        visit: visit,
        actor: @concierge,
        check_out_metadata: {
          access_point: "Main gate",
          incident_type: VisitIncidentTypes::NONE,
          notes: "Left quietly"
        }
      )

      event = visit.visit_status_histories.order(:occurred_at).last

      assert_equal VisitEventTypes::CHECKED_OUT, event.event_type
      assert_equal VisitStatuses::CHECKED_IN, event.from_status
      assert_equal VisitStatuses::CHECKED_OUT, event.to_status
      assert_equal VisitIncidentTypes::NONE, event.metadata.dig("check_out", "incident_type")
    end

    test "cancel records cancelled event" do
      visit = create_authorized_visit!

      Cancel.call(visit: visit, actor: @tenant_admin, notes: "No longer needed")

      event = visit.visit_status_histories.order(:occurred_at).last

      assert_equal VisitEventTypes::CANCELLED, event.event_type
      assert_equal VisitStatuses::AUTHORIZED, event.from_status
      assert_equal VisitStatuses::CANCELLED, event.to_status
      assert_equal "No longer needed", event.notes
    end

    test "create rolls back visit when functional history recording fails" do
      original_call = RecordEvent.method(:call)
      RecordEvent.define_singleton_method(:call) do |**_kwargs|
        invalid = VisitStatusHistory.new
        invalid.errors.add(:event_type, "forced failure")
        raise ActiveRecord::RecordInvalid.new(invalid)
      end

      assert_no_difference -> { Visit.count } do
        assert_no_difference -> { VisitStatusHistory.count } do
          assert_raises(ActiveRecord::RecordInvalid) do
            Create.call(
              unit: @unit,
              visit_params: @visit_params,
              actor: @tenant_admin
            )
          end
        end
      end
    ensure
      RecordEvent.define_singleton_method(:call, original_call)
    end

    test "serializer exposes timeline and actor fields" do
      visit = Create.call(
        unit: @unit,
        visit_params: @visit_params,
        actor: @tenant_admin
      )
      event = visit.visit_status_histories.sole
      payload = Admin::VisitStatusHistorySerializer.new(event).as_json

      assert_equal event.id, payload[:id]
      assert_equal VisitEventTypes::CREATED, payload[:event_type]
      assert_equal I18n.t("frontend.admin.visits.event_types.created"), payload[:event_type_label]
      assert_equal @tenant_admin.id, payload[:actor_user_id]
      assert_equal @tenant_admin.name, payload[:actor_name]
      assert_equal @tenant_admin.email, payload[:actor_email]
      assert_not_nil payload[:occurred_at]
    end

    private

    def create_pending_visit!
      Create.call(
        unit: @unit,
        visit_params: @visit_params,
        actor: @tenant_admin
      )
    end

    def create_authorized_visit!
      visit = create_pending_visit!
      Authorize.call(visit: visit, actor: @tenant_admin)
      visit
    end

    def create_checked_in_visit!
      visit = create_authorized_visit!
      CheckIn.call(visit: visit, actor: @concierge)
      visit
    end
  end
end
