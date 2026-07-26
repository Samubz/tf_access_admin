# frozen_string_literal: true

module Properties
  module Setup
    # Value object describing the recommended structure for a property type.
    #
    # +levels+ is an array of 1 or 2 level hashes, each with:
    #   - +section_type+: a +SectionTypes+ constant for the level
    #   - +label_key+: i18n key for the level label
    #   - +suffix_type+: +:letter+ or +:number+ for generated names
    # +units_in+ is the +section_type+ of the leaf level where units live.
    PropertyStructureFormat = Data.define(:levels, :units_in) do
      def single_level?
        levels.size == 1
      end

      def leaf_level
        levels.last
      end

      def as_json(*)
        {
          "levels" => levels.map { |level| level.transform_keys(&:to_s) },
          "units_in" => units_in
        }
      end
    end
  end
end
