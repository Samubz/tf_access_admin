# frozen_string_literal: true

module Units
  # Tenant-safe unit lookup (improve-units-foundation §6.7–§6.9).
  #
  # Applies to an already policy-scoped relation. Normalizes search input through
  # +Units::NormalizeIdentifier+ before matching +normalized_identifier+.
  class Search
    def self.apply(scope, term: nil, residential_property_id: nil, property_section_id: nil, status: nil)
      new(
        scope,
        term: term,
        residential_property_id: residential_property_id,
        property_section_id: property_section_id,
        status: status
      ).apply
    end

    def initialize(scope, term: nil, residential_property_id: nil, property_section_id: nil, status: nil)
      @scope = scope
      @term = term.to_s.strip.presence
      @residential_property_id = residential_property_id.presence
      @property_section_id = property_section_id
      @status = status.to_s.strip.presence
    end

    def apply
      relation = @scope
      relation = relation.where(residential_property_id: @residential_property_id) if @residential_property_id
      relation = apply_section_filter(relation)
      relation = relation.where(status: @status) if @status
      relation = apply_term(relation) if @term
      relation
    end

    private

    def apply_section_filter(relation)
      return relation if @property_section_id.nil?

      if @property_section_id.to_s == "none"
        relation.where(property_section_id: nil)
      else
        relation.where(property_section_id: @property_section_id)
      end
    end

    def apply_term(relation)
      like = AccentInsensitiveMatch.term(@term)
      name_match = relation.where(
        AccentInsensitiveMatch.where_clause("units.identifier", "units.display_name"),
        term: like
      )
      normalized = Units::NormalizeIdentifier.call(@term)&.normalized_identifier

      if normalized.present?
        relation.where(normalized_identifier: normalized).or(name_match)
      else
        name_match
      end
    end
  end
end
