# frozen_string_literal: true

module Units
  # Restores a soft-deleted unit (improve-units-foundation §3.5–§3.7).
  #
  # Clears +deleted_at+ only; +status+ is preserved, including +archived+
  # (§3.7). Rejects restore when the uniqueness context was reused (§3.6).
  class Restore < Base
    def initialize(actor:, unit:)
      super(actor: actor)
      @unit = unit
    end

    def call
      unless @unit.deleted?
        @unit.errors.add(:base, :not_deleted)
        return Result.invalid(@unit)
      end

      authorize_manage_units!(@unit.residential_property)

      return Result.invalid(@unit) unless reject_inoperative_property!(@unit)

      ::Unit.transaction do
        @unit.with_lock do
          original_deleted_at = @unit.deleted_at
          @unit.deleted_at = nil

          if @unit.property_section.present?
            section = @unit.property_section.reload
            resolved = resolve_and_validate_section(@unit, section)
            if resolved == :invalid
              @unit.deleted_at = original_deleted_at
              return Result.invalid(@unit)
            end
          end

          unless @unit.valid?
            @unit.deleted_at = original_deleted_at
            return Result.invalid(@unit)
          end

          restore_unit
        end
      end
    end

    private

    def restore_unit
      return Result.success(@unit) if @unit.save

      Result.invalid(@unit)
    rescue ActiveRecord::RecordNotUnique => e
      @unit.register_uniqueness_conflict(e)
      Result.conflict(@unit)
    end
  end
end
