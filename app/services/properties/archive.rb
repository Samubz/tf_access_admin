# frozen_string_literal: true

module Properties
  # Non-destructive archive of a property (improve-property-foundation §3.3).
  #
  # Archiving only transitions +status+ to +archived+. It never deletes the
  # record or its dependents (sections, units, related persons, staff
  # assignments, visits, operational data are all preserved — §3.8), never uses
  # +deleted_at+ as the archive state, runs inside a row lock for atomicity, and
  # is idempotent when the property is already archived (§3.7).
  class Archive < Base
    def initialize(actor:, property:)
      super(actor: actor)
      @property = property
    end

    def call
      authorize!(@property, :archive?)

      return Result.noop(@property) if @property.status == PropertyStatuses::ARCHIVED

      @property.with_lock do
        @property.update!(status: PropertyStatuses::ARCHIVED)
      end

      Result.success(@property)
    rescue ActiveRecord::RecordInvalid
      Result.invalid(@property)
    end
  end
end
