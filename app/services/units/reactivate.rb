# frozen_string_literal: true

module Units
  # Explicit reactivation of an archived unit (improve-units-foundation §3.8).
  #
  # Moving from +archived+ to an operational status is not part of +Restore+
  # nor +Update+; it requires this dedicated lifecycle service.
  class Reactivate < Base
    def initialize(actor:, unit:, status: UnitStatuses::AVAILABLE)
      super(actor: actor)
      @unit = unit
      @status = status.to_s.strip.downcase
    end

    def call
      authorize_manage_units!(@unit.residential_property)

      return Result.invalid(@unit) unless reject_inoperative_property!(@unit)

      unless @unit.status == UnitStatuses::ARCHIVED
        @unit.errors.add(:status, :reactivate_requires_archived)
        return Result.invalid(@unit)
      end

      unless UnitStatuses::OPERATIONAL.include?(@status)
        @unit.errors.add(:status, :transition_not_allowed)
        return Result.invalid(@unit)
      end

      @unit.with_lock do
        @unit.update!(status: @status)
      end

      Result.success(@unit)
    rescue ActiveRecord::RecordInvalid
      Result.invalid(@unit)
    end
  end
end
