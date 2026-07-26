# frozen_string_literal: true

module Units
  # Technical soft delete of a unit (improve-units-foundation §3.4).
  #
  # Ordinary flows must not call +destroy+ on +Unit+ directly; this service is
  # the approved channel. It sets +deleted_at+ via acts_as_paranoid, does not
  # change business +status+, and releases the active uniqueness context.
  class SoftDelete < Base
    def initialize(actor:, unit:)
      super(actor: actor)
      @unit = unit
    end

    def call
      authorize_manage_units!(@unit.residential_property)

      if @unit.deleted?
        @unit.errors.add(:base, :already_deleted)
        return Result.invalid(@unit)
      end

      @unit.with_lock do
        @unit.authorize_soft_delete!
        return Result.invalid(@unit) unless @unit.destroy
      end

      Result.success(@unit)
    end
  end
end
