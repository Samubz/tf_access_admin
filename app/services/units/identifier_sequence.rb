# frozen_string_literal: true

module Units
  # "prefix + suffix" identifier generation for manual multiple unit creation
  # (add-manual-section-units), mirroring `Properties::Setup::SectionNameSequence`
  # so both features share the same letter/number sequence semantics. Comparison
  # against existing siblings uses `Units::NormalizeIdentifier` instead of section
  # name normalization, matching the unit uniqueness contract.
  #
  # +index+ is zero-based: index 0 → "A" / "1".
  class IdentifierSequence
    LETTER = :letter
    NUMBER = :number
    LETTER_MAX_INDEX = 25
    NUMBER_MAX_INDEX = 999

    def self.identifier(prefix:, suffix_type:, index:)
      "#{prefix} #{suffix(suffix_type, index)}".strip
    end

    # Returns up to +count+ generated identifiers, skipping siblings whose
    # normalized identifier is already taken. Never parses existing identifiers —
    # only compares complete normalized candidates from the sequence.
    def self.available_identifiers(prefix:, suffix_type:, count:, taken_normalized_identifiers:)
      count = count.to_i
      return [] if count <= 0 || prefix.blank?

      taken = taken_normalized_identifiers.compact.to_set
      limit = suffix_type.to_sym == LETTER ? LETTER_MAX_INDEX : NUMBER_MAX_INDEX
      result = []
      index = 0

      while result.size < count && index <= limit
        candidate = identifier(prefix: prefix, suffix_type: suffix_type, index: index)
        normalized = Units::NormalizeIdentifier.call(candidate)&.normalized_identifier
        result << candidate if normalized.present? && !taken.include?(normalized)
        index += 1
      end

      result
    end

    def self.suffix(suffix_type, index)
      suffix_type.to_sym == LETTER ? ("A".ord + index).chr : (index + 1).to_s
    end
  end
end
