# frozen_string_literal: true

module Units
  # Creates a unit within an authorized property (improve-units-foundation §2.2).
  class Create < Base
    def initialize(actor:, property:, attributes: {}, section_id: nil, allow_initial_status: false)
      super(actor: actor)
      @property             = property
      @attributes           = attributes.to_h.symbolize_keys
      @section_id           = section_id
      @allow_initial_status = allow_initial_status
    end

    def call
      authorize_manage_units!(@property)

      unit = ::Unit.new(descriptive_attributes(@attributes))
      unit.residential_property = @property

      resolved = resolve_section(unit, @property, effective_section_id)
      return Result.invalid(unit) if resolved == :invalid

      unit.property_section = resolved

      apply_initial_status(unit)

      return Result.invalid(unit) unless reject_inoperative_property!(unit)

      # Machine key derived from placement + normalized identifier; client-supplied
      # code is never accepted (hierarchical-code-generation).
      unit.code = DomainCodes::DeriveUnitCode.call(unit: unit)
      save_unit(unit)
    end

    private

    def effective_section_id
      @section_id.presence || @attributes[:property_section_id]
    end

    def apply_initial_status(unit)
      requested = @attributes[:status].to_s.strip.downcase.presence

      if requested.nil? || requested == UnitStatuses::AVAILABLE
        unit.status = UnitStatuses::AVAILABLE
        return
      end

      if @allow_initial_status && UnitStatuses::OPERATIONAL.include?(requested)
        unit.status = requested
        return
      end

      unit.status = UnitStatuses::AVAILABLE
    end
  end
end
