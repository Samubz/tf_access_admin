# frozen_string_literal: true

require "test_helper"

class Visit::InitialStatusTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @property = create_property(@organization, "Visit Initial Status Property")
    @unit = create_unit(@property, "VISIT-IS-101")
    @host = Person.create!(
      organization: @organization,
      display_name: "Initial Status Host",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @visitor = Person.create!(
      organization: @organization,
      display_name: "Initial Status Visitor",
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
      email: "visit-initial-status-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @resident = create_resident_user(
      organization: @organization,
      email: "visit-initial-status-resident@example.test",
      unit: @unit
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "tenant admin requesting authorized resolves to authorized" do
    resolved = Visit::InitialStatus.resolve(
      actor: @tenant_admin,
      unit: @unit,
      requested_status: VisitStatuses::AUTHORIZED
    )

    assert_equal VisitStatuses::AUTHORIZED, resolved
  end

  test "resident without authorize capability resolves to pending even when requesting authorized" do
    resolved = Visit::InitialStatus.resolve(
      actor: @resident,
      unit: @unit,
      requested_status: VisitStatuses::AUTHORIZED
    )

    assert_equal VisitStatuses::PENDING, resolved
  end

  test "resident without authorize capability defaults to pending" do
    resolved = Visit::InitialStatus.resolve(actor: @resident, unit: @unit)

    assert_equal VisitStatuses::PENDING, resolved
  end

  test "assign_initial_status stamps authorization fields when actor can authorize" do
    visit = build_visit
    visit.assign_initial_status!(actor: @tenant_admin, requested_status: VisitStatuses::AUTHORIZED)
    visit.save!

    assert_equal VisitStatuses::AUTHORIZED, visit.status
    assert_equal @tenant_admin.id, visit.created_by_id
    assert_equal @tenant_admin.id, visit.authorized_by_id
    assert_not_nil visit.authorized_at
  end

  test "assign_initial_status ignores unauthorized authorized request" do
    visit = build_visit
    visit.assign_initial_status!(actor: @resident, requested_status: VisitStatuses::AUTHORIZED)
    visit.save!

    assert_equal VisitStatuses::PENDING, visit.status
    assert_equal @resident.id, visit.created_by_id
    assert_nil visit.authorized_by_id
    assert_nil visit.authorized_at
  end

  private

  def build_visit
    Visit.new(
      organization: @organization,
      unit: @unit,
      visitor_person: @visitor,
      scheduled_at: 1.day.from_now,
      valid_from: 1.day.from_now,
      visit_type: VisitTypes::GUEST
    )
  end
end
