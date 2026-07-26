# frozen_string_literal: true

require "test_helper"

module Visits
  # Tests for Visits::ConciergeSearch (OpenSpec concierge-visit-access-flow §8.4
  # and the search portion of §8.11 isolation).
  class ConciergeSearchTest < ActiveSupport::TestCase
    include OperationalPolicyTestHelper

    setup do
      @organization = organizations(:one)
      @other_organization = organizations(:two)
      ActsAsTenant.current_tenant = @organization
      Current.reset

      @property = create_property(@organization, "Search Property P")
      @other_property = create_property(@organization, "Search Property Q")
      @unit = create_unit(@property, "SRCH-101")
      @other_unit = create_unit(@other_property, "SRCH-Q-201")
      @host = Person.create!(
        organization: @organization,
        display_name: "Search Host",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      [ @unit, @other_unit ].each do |u|
        UnitOwnership.create!(
          organization: @organization, person: @host, unit: u,
          ownership_percentage: 100, starts_at: Date.current, status: UnitOwnership::STATUS_ACTIVE
        )
      end

      # property-scoped base, as the controller would pass it
      @scope = Visit.where(residential_property_id: @property.id)
    end

    teardown do
      ActsAsTenant.current_tenant = nil
      Current.reset
    end

    # ─── 8.4 search criteria ──────────────────────────────────────────────────

    test "search matches by visitor document" do
      visit = build_visit!(unit: @unit, visitor_name: "Doc Visitor", document: "SRCH-DOC-1")
      results = ConciergeSearch.call(scope: @scope, query: "SRCH-DOC-1", organization: @organization)
      assert_includes results, visit
    end

    test "search matches by partial visitor name" do
      visit = build_visit!(unit: @unit, visitor_name: "Alejandra Soto")
      results = ConciergeSearch.call(scope: @scope, query: "alejand", organization: @organization)
      assert_includes results, visit
    end

    test "search matches by unit identifier" do
      visit = build_visit!(unit: @unit, visitor_name: "Unit Match")
      results = ConciergeSearch.call(scope: @scope, query: "SRCH-101", organization: @organization)
      assert_includes results, visit
    end

    test "blank query returns the scope unchanged" do
      build_visit!(unit: @unit, visitor_name: "Anyone")
      results = ConciergeSearch.call(scope: @scope, query: "  ", organization: @organization)
      assert_equal @scope.to_a.sort_by(&:id), results.to_a.sort_by(&:id)
    end

    # ─── 8.6 / 2.6 operational base excludes cancelled and expired ─────────────

    test "normal search excludes cancelled visits" do
      cancelled = build_visit!(unit: @unit, visitor_name: "Cancelled One", status: VisitStatuses::CANCELLED)
      results = ConciergeSearch.call(scope: @scope, query: "Cancelled", organization: @organization)
      refute_includes results, cancelled
    end

    # ─── 2.5 denied-result path can surface a cancelled visit ──────────────────

    test "denied search surfaces a cancelled visit to explain denial" do
      cancelled = build_visit!(unit: @unit, visitor_name: "Denied Cancelled", status: VisitStatuses::CANCELLED)
      results = ConciergeSearch.call(scope: @scope, query: "Denied Cancelled",
                                     organization: @organization, include_denied: true)
      assert_includes results, cancelled
    end

    # ─── 8.11 isolation ────────────────────────────────────────────────────────

    test "search never crosses into another property within the same scope" do
      other = build_visit!(unit: @other_unit, visitor_name: "Cross Property", document: "SRCH-DOC-X")
      by_name = ConciergeSearch.call(scope: @scope, query: "Cross Property", organization: @organization)
      by_doc = ConciergeSearch.call(scope: @scope, query: "SRCH-DOC-X", organization: @organization)
      refute_includes by_name, other
      refute_includes by_doc, other
    end

    test "document search is scoped to the passed organization" do
      visit = build_visit!(unit: @unit, visitor_name: "Org Scoped", document: "SRCH-ORG-1")
      cross_org = ConciergeSearch.call(scope: @scope, query: "SRCH-ORG-1", organization: @other_organization)
      refute_includes cross_org, visit
    end

    private

    def build_visit!(unit:, visitor_name:, document: nil, status: VisitStatuses::AUTHORIZED)
      ActsAsTenant.with_tenant(@organization) do
        visitor = Person.new(
          organization: @organization,
          display_name: visitor_name,
          person_type: PersonTypes::NATURAL,
          status: PersonStatuses::ACTIVE
        )
        visitor.document_number = document if document
        visitor.save!

        Visit.create!(
          organization: @organization,
          unit: unit,
          visitor_person: visitor,
          scheduled_at: 1.hour.from_now,
          valid_from: 1.hour.ago,
          status: status
        )
      end
    end
  end
end
