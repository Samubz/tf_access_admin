# frozen_string_literal: true

module Properties
  module Setup
    # Removes a unit through the wizard (manual delete or structure reset):
    # soft-deletes it directly when it has no operational history, or requires
    # explicit confirmation and archives it (status-only, non-destructive) when
    # it does. Does not change `Units::Archive`/`Units::Reactivate`
    # (enable-wizard-editing-created-state).
    class RemoveUnit
      def self.call(...) = new(...).call

      def initialize(actor:, unit:, confirmed: false)
        @actor = actor
        @unit = unit
        @confirmed = confirmed
      end

      def call
        if Units::HasOperationalHistory.call(@unit)
          return RemovalOutcome.needs_confirmation(@unit) unless @confirmed

          result = Units::Archive.call(actor: @actor, unit: @unit)
          return RemovalOutcome.invalid(result.unit) if result.invalid?

          RemovalOutcome.archived(result.unit)
        else
          result = Units::SoftDelete.call(actor: @actor, unit: @unit)
          return RemovalOutcome.invalid(result.unit) if result.invalid?

          RemovalOutcome.removed(result.unit)
        end
      end
    end
  end
end
