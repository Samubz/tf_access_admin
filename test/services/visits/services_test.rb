# frozen_string_literal: true

require "test_helper"

module Visits
  class ServicesTest < ActiveSupport::TestCase
    include OperationalPolicyTestHelper
    include ActiveJob::TestHelper

    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization
      Current.organization = @organization

      @property = create_property(@organization, "Visit Services Property")
      @unit = create_unit(@property, "VISIT-SRV-101")
      @host = Person.create!(
        organization: @organization,
        display_name: "Services Host",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      @visitor = Person.create!(
        organization: @organization,
        display_name: "Services Visitor",
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
        email: "visit-services-admin@example.test",
        role: AvailableRoles::TENANT_ADMIN
      )
      @concierge = create_staff_user(
        organization: @organization,
        email: "visit-services-concierge@example.test",
        staff_type: StaffTypes::CONCIERGE,
        property: @property
      )
      @resident = create_resident_user(
        organization: @organization,
        email: "visit-services-resident@example.test",
        unit: @unit
      )

      @visit_params = {
        visitor_person_id: @visitor.id,
        scheduled_at: 1.hour.from_now,
        valid_from: 1.hour.ago,
        valid_until: 2.hours.from_now,
        visit_type: VisitTypes::GUEST,
        metadata: {
          vehicle: { plate: "SVC123", brand_model: "Honda", color: "Blue", vin: "drop" }
        }
      }
    end

    teardown do
      ActsAsTenant.current_tenant = nil
      Current.reset
    end

    test "create persists denormalized location and sanitized metadata" do
      visit = Create.call(
        unit: @unit,
        visit_params: @visit_params,
        actor: @tenant_admin,
        requested_status: VisitStatuses::AUTHORIZED
      )

      assert_equal @property.id, visit.residential_property_id
      assert_equal @unit.id, visit.unit_id
      assert_equal VisitStatuses::AUTHORIZED, visit.status
      assert_equal @tenant_admin.id, visit.created_by_id
      assert_equal "SVC123", visit.vehicle_metadata["plate"]
      refute visit.metadata.dig("vehicle", "vin")
    end

    test "create succeeds without any host-related param" do
      refute @visit_params.key?(:host_person_id)

      visit = Create.call(
        unit: @unit,
        visit_params: @visit_params,
        actor: @tenant_admin,
        requested_status: VisitStatuses::AUTHORIZED
      )

      assert visit.persisted?
    end

    test "create enqueues notification delivery for the unit's active authorizer" do
      resident_user = create_resident_user(
        organization: @organization,
        email: "visit-services-authorizer@example.test",
        unit: @unit
      )
      UnitOccupancy.find_by(person: resident_user.person_for(@organization), unit: @unit)
                   .update!(can_authorize_visits: true)

      visit = nil
      assert_enqueued_jobs 1, only: DeliverPushNotificationJob do
        visit = Create.call(unit: @unit, visit_params: @visit_params, actor: @tenant_admin)
      end

      assert_equal 1, visit.notifications.count
    end

    test "a failure in notification creation does not roll back the created visit" do
      original_call = Notifications::CreateForVisit.method(:call)
      Notifications::CreateForVisit.define_singleton_method(:call) { |**| raise "boom" }

      assert_raises(RuntimeError) do
        Create.call(unit: @unit, visit_params: @visit_params, actor: @tenant_admin)
      end

      assert Visit.exists?(unit: @unit, visitor_person_id: @visitor.id)
    ensure
      Notifications::CreateForVisit.define_singleton_method(:call, original_call)
    end

    test "resident create resolves pending initial status in backend" do
      visit = Create.call(
        unit: @unit,
        visit_params: @visit_params,
        actor: @resident,
        requested_status: VisitStatuses::AUTHORIZED
      )

      assert_equal VisitStatuses::PENDING, visit.status
      assert_equal @resident.id, visit.created_by_id
      assert_nil visit.authorized_by_id
    end

    test "concierge cannot create visits" do
      assert_no_difference -> { Visit.count } do
        assert_raises(Pundit::NotAuthorizedError) do
          Create.call(
            unit: @unit,
            visit_params: @visit_params,
            actor: @concierge
          )
        end
      end
    end

    test "concierge cannot authorize visits" do
      visit = create_pending_visit!(actor: @tenant_admin)

      assert_raises(Pundit::NotAuthorizedError) do
        Authorize.call(visit: visit, actor: @concierge)
      end
    end

    test "concierge cannot cancel visits" do
      visit = create_authorized_visit!(actor: @tenant_admin)

      assert_raises(Pundit::NotAuthorizedError) do
        Cancel.call(visit: visit, actor: @concierge)
      end
    end

    test "check_in accepts explicit operational fields and drops unknown metadata" do
      visit = create_authorized_visit!(actor: @tenant_admin)

      CheckIn.call(
        visit: visit,
        actor: @concierge,
        access_point: "Main gate",
        access_type: VisitAccessTypes::VEHICLE,
        vehicle_plate: "SVC123",
        notes: "Entry confirmed",
        check_in_metadata: { unexpected: "drop", notes: "Arrived by car" }
      )

      assert_equal VisitStatuses::CHECKED_IN, visit.reload.status
      assert_equal "Main gate", visit.check_in_metadata["access_point"]
      assert_equal VisitAccessTypes::VEHICLE, visit.check_in_metadata["access_type"]
      assert_equal "SVC123", visit.check_in_metadata["vehicle_plate"]
      assert_equal "Arrived by car", visit.check_in_metadata["notes"]
      refute visit.metadata.dig("check_in", "unexpected")
    end

    test "check_out accepts explicit operational fields" do
      visit = create_checked_in_visit!(actor: @tenant_admin, concierge: @concierge)

      CheckOut.call(
        visit: visit,
        actor: @concierge,
        access_point: "Side gate",
        incident_type: VisitIncidentTypes::NONE,
        notes: "Exit confirmed",
        check_out_metadata: { notes: "Left quietly" }
      )

      assert_equal VisitStatuses::CHECKED_OUT, visit.reload.status
      assert_equal "Side gate", visit.check_out_metadata["access_point"]
      assert_equal VisitIncidentTypes::NONE, visit.check_out_metadata["incident_type"]
      assert_equal "Left quietly", visit.check_out_metadata["notes"]
    end

    test "check_in rejects invalid access type before transition" do
      visit = create_authorized_visit!(actor: @tenant_admin)

      assert_raises(Visits::OperationalMetadataParams::InvalidMetadataError) do
        CheckIn.call(
          visit: visit,
          actor: @concierge,
          access_type: "hoverboard"
        )
      end

      assert_equal VisitStatuses::AUTHORIZED, visit.reload.status
    end

    test "authorize rolls back visit and history on failure" do
      visit = create_pending_visit!(actor: @tenant_admin)
      original_call = RecordEvent.method(:call)
      RecordEvent.define_singleton_method(:call) do |**_kwargs|
        invalid = VisitStatusHistory.new
        invalid.errors.add(:event_type, "forced failure")
        raise ActiveRecord::RecordInvalid.new(invalid)
      end

      assert_raises(ActiveRecord::RecordInvalid) do
        Authorize.call(visit: visit, actor: @tenant_admin)
      end

      assert_equal VisitStatuses::PENDING, visit.reload.status
      assert_equal 1, visit.visit_status_histories.count
    ensure
      RecordEvent.define_singleton_method(:call, original_call)
    end

    private

    def create_pending_visit!(actor:)
      Create.call(
        unit: @unit,
        visit_params: @visit_params,
        actor: actor
      )
    end

    def create_authorized_visit!(actor:)
      visit = create_pending_visit!(actor: actor)
      Authorize.call(visit: visit, actor: actor)
      visit
    end

    def create_checked_in_visit!(actor:, concierge:)
      visit = create_authorized_visit!(actor: actor)
      CheckIn.call(visit: visit, actor: concierge)
      visit
    end
  end
end
