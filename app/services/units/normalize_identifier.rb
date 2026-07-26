# frozen_string_literal: true

module Units
  # Canonical identifier normalization for units (improve-units-foundation §2.1).
  #
  # Single source of truth for model, services, bulk import, search and backfill.
  # Pure: no database queries, no side effects.
  #
  # Returns a frozen struct with +identifier+ (trimmed, presentation-safe) and
  # +normalized_identifier+ (case-folded, hyphenated). Returns +nil+ when the
  # input is blank or whitespace-only.
  NormalizeIdentifierResult = Data.define(:identifier, :normalized_identifier)

  class NormalizeIdentifier
    def self.call(raw)
      trimmed = raw.to_s.strip
      return nil if trimmed.empty?

      new(trimmed).call
    end

    def initialize(trimmed)
      @trimmed = trimmed
    end

    def call
      NormalizeIdentifierResult.new(
        identifier: @trimmed,
        # Transliterating slug so `Área 4` and `Area 4` normalize to the same
        # `area-4` and align with property/section codes (hierarchical-code-generation).
        normalized_identifier: DomainCodes::Slug.call(@trimmed)
      )
    end
  end
end
