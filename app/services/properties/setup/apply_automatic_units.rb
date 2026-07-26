# frozen_string_literal: true

module Properties
  module Setup
    # Generates the automatic unit batch for wizard step 3 (quick structure only).
    #
    # Delegates the "which units, where, with which identifier/type" decision to
    # the shared {UnitGenerationPlan} (so the persisted result matches the step 3
    # preview) and creates each planned unit through {Units::Create}, keeping all
    # normalization/uniqueness/code-derivation rules in the +unit+ contract
    # (fix-automatic-unit-generation §4).
    #
    # Idempotent per row: a planned unit whose +(property_section, normalized
    # identifier)+ already exists on a non-deleted unit is skipped, so a resumed
    # wizard fills in only what's missing without duplicating. A skipped row whose
    # existing unit differs in +unit_type+ is reported as a non-blocking warning.
    class ApplyAutomaticUnits < Base
      def initialize(actor:, property:, params: {})
        super(actor: actor)
        @property = property
        @params = params.to_h.with_indifferent_access
        @warnings = []
      end

      attr_reader :warnings

      def call
        authorize_setup_property!(@property)

        plan = UnitGenerationPlan.new(property: @property, format: format, params: @params)
        unless plan.available?
          @property.errors.add(:base, :automatic_generation_unavailable)
          return Result.invalid(@property)
        end

        plan.rows.each do |row|
          next if existing_unit_for(row)

          result = Units::Create.call(
            actor: @actor,
            property: @property,
            section_id: row.property_section&.id,
            attributes: { identifier: row.identifier, unit_type: row.unit_type }
          )

          return Result.invalid(@property) unless result.success?
        end

        Result.success(@property)
      end

      private

      def format
        @format ||= StructureFormatResolver.for(property_type: @property.property_type)
      end

      # Matches an existing non-deleted unit at the exact planned placement and
      # normalized identifier. When one exists with a different +unit_type+, the
      # row is skipped and a non-blocking warning is recorded rather than
      # overwriting the existing unit.
      def existing_unit_for(row)
        return false if row.normalized_identifier.blank?

        existing = @property.units.find_by(
          property_section_id: row.property_section&.id,
          normalized_identifier: row.normalized_identifier
        )
        return false if existing.nil?

        if existing.unit_type != row.unit_type
          @warnings << { identifier: row.identifier, expected: row.unit_type, actual: existing.unit_type }
        end

        true
      end
    end
  end
end
