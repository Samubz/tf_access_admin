# frozen_string_literal: true

require "test_helper"

# Tests for concierge operational scopes (OpenSpec concierge-visit-access-flow §8.5)
# and the tenant-safe document search scope (§8.1 building block).
class VisitOperationalScopesTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property = create_property(@organization, "Op Scopes Property")
    @unit = create_unit(@property, "OPS-101")
    @host = @owner_person = Person.create!(
      organization: @organization,
      display_name: "Op Scopes Host",
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
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  # ─── 8.5 expected_today ───────────────────────────────────────────────────────

  test "expected_today includes authorized visit scheduled today" do
    today = build_visit!(status: VisitStatuses::AUTHORIZED, scheduled_at: Time.zone.now.change(hour: 12))
    assert_includes Visit.expected_today, today
  end

  test "expected_today includes authorized visit whose validity window intersects today" do
    spanning = build_visit!(
      status: VisitStatuses::AUTHORIZED,
      scheduled_at: 2.days.from_now.change(hour: 9),
      valid_from: 1.day.ago,
      valid_until: 1.day.from_now
    )
    assert_includes Visit.expected_today, spanning
  end

  test "expected_today excludes authorized visit scheduled tomorrow outside window" do
    tomorrow = build_visit!(
      status: VisitStatuses::AUTHORIZED,
      scheduled_at: 1.day.from_now.change(hour: 10),
      valid_from: 1.day.from_now.change(hour: 9)
    )
    refute_includes Visit.expected_today, tomorrow
  end

  test "expected_today excludes non-authorized statuses" do
    checked_in = build_visit!(status: VisitStatuses::CHECKED_IN, scheduled_at: Time.zone.now.change(hour: 12),
                              checked_in_at: 1.hour.ago)
    refute_includes Visit.expected_today, checked_in
  end

  test "expected_today orders by scheduled_at ascending" do
    later = build_visit!(status: VisitStatuses::AUTHORIZED, scheduled_at: Time.zone.now.change(hour: 18))
    earlier = build_visit!(status: VisitStatuses::AUTHORIZED, scheduled_at: Time.zone.now.change(hour: 8))
    ordered = Visit.expected_today.to_a
    assert_operator ordered.index(earlier), :<, ordered.index(later)
  end

  # ─── 8.5 currently_inside ─────────────────────────────────────────────────────

  test "currently_inside includes checked_in visits without exit" do
    inside = build_visit!(status: VisitStatuses::CHECKED_IN, checked_in_at: 2.hours.ago)
    assert_includes Visit.currently_inside, inside
  end

  test "currently_inside excludes checked_out visits" do
    out = build_visit!(status: VisitStatuses::CHECKED_OUT, checked_in_at: 3.hours.ago, checked_out_at: 1.hour.ago)
    refute_includes Visit.currently_inside, out
  end

  test "currently_inside excludes authorized visits" do
    authorized = build_visit!(status: VisitStatuses::AUTHORIZED, scheduled_at: Time.zone.now)
    refute_includes Visit.currently_inside, authorized
  end

  test "currently_inside orders by oldest entry first" do
    newer = build_visit!(status: VisitStatuses::CHECKED_IN, checked_in_at: 1.hour.ago)
    older = build_visit!(status: VisitStatuses::CHECKED_IN, checked_in_at: 5.hours.ago)
    ordered = Visit.currently_inside.to_a
    assert_operator ordered.index(older), :<, ordered.index(newer)
  end

  # ─── by_visitor_document (tenant-safe) ────────────────────────────────────────

  test "by_visitor_document matches the visitor's document within the organization" do
    visit = build_visit!(status: VisitStatuses::AUTHORIZED, scheduled_at: Time.zone.now, visitor_document: "DOC-OPS-1")
    result = Visit.by_visitor_document("DOC-OPS-1", organization: @organization)
    assert_includes result, visit
  end

  test "by_visitor_document returns none for blank input" do
    assert_empty Visit.by_visitor_document("", organization: @organization)
  end

  test "by_visitor_document does not match a document from another organization" do
    build_visit!(status: VisitStatuses::AUTHORIZED, scheduled_at: Time.zone.now, visitor_document: "DOC-SHARED")

    other_org_match = Visit.by_visitor_document("DOC-SHARED", organization: @other_organization)
    assert_empty other_org_match
  end

  private

  def build_visit!(status:, scheduled_at: 1.hour.from_now, valid_from: nil, valid_until: nil,
                   checked_in_at: nil, checked_out_at: nil, visitor_document: nil)
    ActsAsTenant.with_tenant(@organization) do
      visitor = Person.new(
        organization: @organization,
        display_name: "Visitor #{SecureRandom.hex(4)}",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      visitor.document_number = visitor_document if visitor_document
      visitor.save!

      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: visitor,
        scheduled_at: scheduled_at,
        valid_from: valid_from || scheduled_at,
        valid_until: valid_until,
        status: status,
        checked_in_at: checked_in_at,
        checked_out_at: checked_out_at
      )
    end
  end
end
