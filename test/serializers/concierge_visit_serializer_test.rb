# frozen_string_literal: true

require "test_helper"

# Minimal-payload / no-administrative-data tests for the concierge serializers
# (OpenSpec concierge-visit-access-flow §8.12, building on §5).
class ConciergeVisitSerializerTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property = create_property(@organization, "Serializer Property")
    @unit = create_unit(@property, "SER-101")
    @host = Person.create!(
      organization: @organization, display_name: "Serializer Host",
      person_type: PersonTypes::NATURAL, status: PersonStatuses::ACTIVE
    )
    UnitOwnership.create!(
      organization: @organization, person: @host, unit: @unit,
      ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
    )
    @tenant_admin = create_user_for_organization(
      organization: @organization, email: "ser-admin@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    @concierge = create_staff_user(
      organization: @organization, email: "ser-concierge@example.test",
      staff_type: StaffTypes::CONCIERGE, property: @property
    )

    visitor = Person.new(
      organization: @organization, display_name: "Serializer Visitor",
      person_type: PersonTypes::NATURAL, status: PersonStatuses::ACTIVE
    )
    visitor.document_number = "SER-DOC-1"
    visitor.save!

    @visit = ActsAsTenant.with_tenant(@organization) do
      Visit.create!(
        organization: @organization, unit: @unit, visitor_person: visitor,
        scheduled_at: 1.hour.from_now, valid_from: 1.hour.ago, valid_until: 3.hours.from_now,
        status: VisitStatuses::CHECKED_IN, checked_in_at: 30.minutes.ago, checked_in_by_id: @concierge.id,
        authorized_at: 2.hours.ago, authorized_by_id: @tenant_admin.id,
        notes: "internal admin note", metadata: { "vehicle" => { "plate" => "XX99" } }
      )
    end
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  def row_payload
    Current.organization = @organization
    Current.user = @concierge
    Concierge::VisitSerializer.new(@visit, current_user: @concierge).as_json
  end

  # ─── 8.12 minimal payload ─────────────────────────────────────────────────

  test "row payload exposes operational fields" do
    payload = row_payload
    assert_equal @visit.id, payload[:id]
    assert_equal VisitStatuses::CHECKED_IN, payload[:status]
    assert_equal "Serializer Visitor", payload[:visitor][:display_name]
    assert_equal @unit.identifier, payload[:unit][:identifier]
    assert payload.key?(:duration_seconds)
    assert payload.key?(:effective_status)
    assert payload.key?(:permissions)
    assert payload.key?(:actions)
  end

  test "row payload visitor is a minimal summary without document or profile" do
    visitor = row_payload[:visitor]
    assert_equal %i[id display_name].sort, visitor.keys.sort
  end

  # ─── 8.12 no administrative data ──────────────────────────────────────────

  test "row payload does not leak notes, metadata or audit data" do
    payload = row_payload
    refute payload.key?(:notes)
    refute payload.key?(:metadata)
    refute payload.key?(:audits)
    refute payload.key?(:reason)
  end

  test "row payload exposes only summarized actor names, not actor records" do
    payload = row_payload
    assert payload.key?(:checked_in_by_name)
    refute payload.key?(:checked_in_by)
    refute payload.key?(:authorized_by)
    refute payload.key?(:checked_out_by)
  end

  test "effective status maps a lapsed authorization to expired" do
    @visit.update_columns(status: VisitStatuses::AUTHORIZED, valid_until: 1.hour.ago)
    assert_equal VisitStatuses::EXPIRED, row_payload[:effective_status]
  end
end
