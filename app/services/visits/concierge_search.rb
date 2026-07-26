# frozen_string_literal: true

module Visits
  # Operational search for concierge actors (OpenSpec concierge-visit-access-flow §2).
  #
  # Security contract (2.4):
  #   The caller MUST supply a `scope:` that is already narrowed to the current
  #   organization AND the active property (via `property_scoped_visits`).
  #   This service never adds its own org/property filter — it only refines the
  #   pre-scoped relation so that scope ordering is always: org → property → search.
  #
  # Search criteria are combined with OR:
  #   2.1 — visitor document:  exact blind-index digest match within the org
  #   2.2 — visitor name:      case-insensitive partial match on display_name
  #   2.3 — unit identifier:   partial match on identifier, normalized_identifier or display_name
  #
  # Visibility (2.5 / 2.6):
  #   Normal mode (include_denied: false) — base is `concierge_visible`:
  #     authorized, checked_in, recently checked_out; cancelled/expired excluded.
  #   Denied mode  (include_denied: true)  — base is the raw scope:
  #     can surface a cancelled or expired visit to explain entry denial.
  #     Only use this path when the query is specific (e.g. exact document).
  class ConciergeSearch
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(scope:, query:, organization:, include_denied: false)
      @scope          = scope
      @query          = query.to_s.strip.presence
      @organization   = organization
      @include_denied = include_denied
    end

    # Returns an AR relation. When query is blank the pre-scoped relation is
    # returned unchanged so upstream callers can add ordering/pagination as usual.
    def call
      return @scope if @query.blank?

      # 2.6 — operational base strips cancelled/expired unless denied-result path (2.5)
      base = @include_denied ? @scope : @scope.concierge_visible

      like = "%#{sanitize_like(@query)}%"
      digest = Person.document_digest(@query)

      # Single query joining visitor (people) and unit so all three criteria can
      # be OR'd in one WHERE. Combining them as separate `.or` relations fails
      # because each carries a different join and is structurally incompatible.
      #   2.1 — exact document digest, scoped to the organization
      #   2.2 — partial visitor name (ILIKE, accent-tolerant case-insensitivity)
      #   2.3 — unit identifier, normalized identifier or visible name
      base
        .joins(:visitor_person, :unit)
        .where(
          "(people.organization_id = :org AND people.document_number_digest = :digest) " \
          "OR people.display_name ILIKE :like " \
          "OR units.identifier ILIKE :like OR units.normalized_identifier ILIKE :like " \
          "OR units.display_name ILIKE :like",
          org: @organization.id, digest: digest, like: like
        )
    end

    private

    # Escape ILIKE wildcards to prevent user input from acting as patterns.
    def sanitize_like(str)
      str.gsub(/[%_\\]/) { |c| "\\#{c}" }
    end
  end
end
