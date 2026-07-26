# frozen_string_literal: true

module Properties
  module Setup
    # Single source of truth for section naming: "prefix + suffix", where the
    # suffix is a letter (A, B, C…) or a number (1, 2, 3…). Shared by the quick
    # structure engine (`GenerateStructurePreview`, `ApplyQuickStructure`) and the
    # manual builder batch (`PropertySections::CreateBatch`) so every producer
    # agrees on the generated names. Mirrored on the front end in
    # `structurePreview.ts` for the manual modal's live "De creación" preview.
    #
    # +index+ is zero-based: index 0 → "A" / "1".
    class SectionNameSequence
      LETTER = :letter
      NUMBER = :number
      LETTER_MAX_INDEX = 25
      NUMBER_MAX_INDEX = 999

      def self.name(prefix:, suffix_type:, index:)
        "#{prefix} #{suffix(suffix_type, index)}".strip
      end

      def self.names(prefix:, suffix_type:, count:)
        Array.new([ count.to_i, 0 ].max) do |index|
          name(prefix: prefix, suffix_type: suffix_type, index: index)
        end
      end

      # Returns up to +count+ generated names, skipping siblings whose full
      # normalized name is already taken. Never parses existing names — only
      # compares complete normalized candidates from the sequence.
      def self.available_names(prefix:, suffix_type:, count:, taken_normalized_names:)
        count = count.to_i
        return [] if count <= 0 || prefix.blank?

        taken = taken_normalized_names.compact.to_set
        limit = suffix_type.to_sym == LETTER ? LETTER_MAX_INDEX : NUMBER_MAX_INDEX
        result = []
        index = 0

        while result.size < count && index <= limit
          candidate = name(prefix: prefix, suffix_type: suffix_type, index: index)
          normalized = PropertySection.normalize_name(candidate)
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
end
