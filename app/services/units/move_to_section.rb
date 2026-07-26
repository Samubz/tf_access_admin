# frozen_string_literal: true

module Units
  # Moves a unit to a different section within the same property
  # (improve-units-foundation §2.4).
  class MoveToSection < Base
    SECTION_UNCHANGED = :section_unchanged

    def initialize(actor:, unit:, section_id: SECTION_UNCHANGED)
      super(actor: actor)
      @unit       = unit
      @section_id = section_id
    end

    def call
      authorize_manage_units!(@unit.residential_property)

      return Result.invalid(@unit) unless reject_inoperative_property!(@unit)
      return Result.noop(@unit) if section_unchanged?

      target_section = resolve_target_section
      return Result.invalid(@unit) if target_section == :invalid

      ::Unit.transaction do
        @unit.with_lock do
          @unit.property_section = target_section
          save_unit(@unit)
        end
      end
    end

    private

    def section_unchanged?
      return true if @section_id == SECTION_UNCHANGED
      return true if @section_id.to_s == @unit.property_section_id.to_s

      false
    end

    def resolve_target_section
      return nil if @section_id.nil?

      resolve_section(@unit, @unit.residential_property, @section_id)
    end
  end
end
