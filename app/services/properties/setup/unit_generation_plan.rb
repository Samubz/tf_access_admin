# frozen_string_literal: true

module Properties
  module Setup
    # Pure calculator shared by the units preview (+GenerateUnitsPreview+) and the
    # apply step (+ApplyAutomaticUnits+) so both derive the exact same set of
    # planned units from the same inputs (fix-automatic-unit-generation §1).
    #
    # Given a draft property (whose leaf sections already exist), the resolved
    # +PropertyStructureFormat+, and the +unit_generation+ params, it returns one
    # +Row+ per planned unit. It performs NO persistence and NO uniqueness checks —
    # those stay in +Units::Create+ / +Unit+.
    #
    # Automatic generation is only meaningful when a structure format resolves and
    # the property has leaf sections of the format's +units_in+ type. When no
    # format resolves, {#available?} is false and {#rows} is empty (no flat,
    # unsectioned fallback batch is produced for automatic mode).
    class UnitGenerationPlan
      DEFAULT_UNITS_PER_LEAF = 4

      # One planned unit. +normalized_identifier+ mirrors what +Units::Create+
      # would derive, so callers can match against persisted rows for idempotency
      # without re-normalizing.
      Row = Data.define(:property_section, :identifier, :normalized_identifier, :unit_type)

      def self.call(property:, format:, params: {})
        new(property: property, format: format, params: params).rows
      end

      def initialize(property:, format:, params: {})
        @property = property
        @format = format
        @params = params.to_h.with_indifferent_access
      end

      # @return [Boolean] whether automatic generation can run for this property.
      def available?
        @format.present? && leaf_sections.any?
      end

      # @return [Array<Row>] one row per planned unit, grouped by leaf section.
      def rows
        return [] unless available?

        leaf_sections.flat_map do |leaf|
          units_per_leaf.times.map do |index|
            build_row(leaf, index)
          end
        end
      end

      # Leaf sections in a stable order, so identifier numbering is deterministic.
      def leaf_sections
        @leaf_sections ||= @property.property_sections
          .where(section_type: @format.units_in)
          .order(:position, :name)
          .to_a
      end

      private

      def build_row(leaf, index)
        identifier = identifier_for(leaf, index)
        normalized = Units::NormalizeIdentifier.call(identifier)

        Row.new(
          property_section: leaf,
          identifier: identifier,
          normalized_identifier: normalized&.normalized_identifier,
          unit_type: unit_type
        )
      end

      # Identifier numbering strategies (fix-automatic-unit-generation §1.3-1.5):
      # - floor_sequential / block_sequential are position-based
      #   (+leaf.position * 100 + index + 1+), the block variant adding a +B+
      #   prefix. Both start at 101 / B101 for position 1.
      # - sequential resets to 1 at the start of every leaf section.
      def identifier_for(leaf, index)
        case identifier_format
        when "block_sequential"
          "B#{position_base(leaf) + index + 1}"
        when "sequential"
          (index + 1).to_s
        else # "floor_sequential" (default)
          (position_base(leaf) + index + 1).to_s
        end
      end

      def position_base(leaf)
        position = leaf.position.to_i
        position = 1 if position <= 0

        position * 100
      end

      def identifier_format
        @identifier_format ||= @params[:identifier_format].to_s.strip.presence || "floor_sequential"
      end

      def unit_type
        @unit_type ||= @params[:unit_type].to_s.strip.presence || UnitTypes::APARTMENT
      end

      def units_per_leaf
        value = @params[:units_per_leaf].to_i
        value.positive? ? value : DEFAULT_UNITS_PER_LEAF
      end
    end
  end
end
