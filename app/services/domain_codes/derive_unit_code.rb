# frozen_string_literal: true

module DomainCodes
  # Derives a unit code from its placement plus the canonical
  # `normalized_identifier` segment (hierarchical-code-generation §Unit code):
  #
  #   sectioned:  {section_code}-{normalized_identifier}
  #   root-level: {property_code}-{normalized_identifier}
  #
  # Uses the normalized identifier (transliterating slug), never the raw human
  # `identifier`. Collision scope matches the unit code unique indexes:
  # (organization, residential_property, property_section_id, code).
  class DeriveUnitCode
    def self.call(unit:)
      new(unit: unit).call
    end

    def initialize(unit:)
      @unit = unit
    end

    def call
      return if base.blank?

      CollisionResolver.call(base: base) { |candidate| taken?(candidate) }
    end

    private

    # Prefer the already-assigned normalized_identifier; fall back to normalizing
    # the raw identifier when derivation runs before model validation.
    def segment
      @segment ||= @unit.normalized_identifier.presence ||
                   Units::NormalizeIdentifier.call(@unit.identifier)&.normalized_identifier.to_s
    end

    def prefix
      @unit.property_section&.code.presence || @unit.residential_property&.code
    end

    def base
      @base ||= [ prefix, segment ].reject(&:blank?).join("-")
    end

    def taken?(candidate)
      scope = Unit.where(
        residential_property_id: @unit.residential_property_id,
        property_section_id: @unit.property_section_id,
        code: candidate
      )
      scope = scope.where.not(id: @unit.id) if @unit.id
      scope.exists?
    end
  end
end
