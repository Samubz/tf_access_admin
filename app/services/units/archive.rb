# frozen_string_literal: true

module Units
  # Non-destructive archive of a unit (improve-units-foundation §3.1–§3.2).
  #
  # Archive is a business-lifecycle transition: +status = archived+ only.
  # It never calls +destroy+, never sets +deleted_at+, and keeps the identifier
  # reserved in the active uniqueness context (§3.3).
  class Archive < Base
    def initialize(actor:, unit:)
      super(actor: actor)
      @unit = unit
    end

    def call
      authorize_manage_units!(@unit.residential_property)

      return Result.invalid(@unit) unless reject_inoperative_property!(@unit)
      return Result.noop(@unit) if @unit.status == UnitStatuses::ARCHIVED

      @unit.with_lock do
        @unit.update!(status: UnitStatuses::ARCHIVED)
      end

      Result.success(@unit)
    rescue ActiveRecord::RecordInvalid
      Result.invalid(@unit)
    end
  end
end
