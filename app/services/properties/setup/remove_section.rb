# frozen_string_literal: true

module Properties
  module Setup
    # Removes a single section (and its own units) through the wizard's manual
    # structure management. Soft-deletes both directly when none of the
    # section's units has operational history, or requires explicit
    # confirmation and archives both (status-only, non-destructive) when any
    # does. A section with child sections cannot be removed this way at all —
    # `PropertySection`'s `dependent: :restrict_with_error` on :children blocks
    # the soft-delete path until the children are removed individually, and
    # archiving a section with children is allowed (it never touches
    # associations), with children becoming effectively archived through
    # inherited visibility rather than a real status change
    # (enable-wizard-editing-created-state).
    class RemoveSection
      def self.call(...) = new(...).call

      def initialize(actor:, section:, confirmed: false)
        @actor = actor
        @section = section
        @confirmed = confirmed
      end

      def call
        if PropertySections::HasOperationalHistory.call(@section)
          return RemovalOutcome.needs_confirmation(@section) unless @confirmed

          with_transaction { archive_section_and_units }
        else
          with_transaction { soft_delete_section_and_units }
        end
      end

      private

      # All-or-nothing: if any step fails, roll back the whole removal instead
      # of leaving a partially archived/soft-deleted section+units.
      def with_transaction
        outcome = nil
        ActiveRecord::Base.transaction do
          outcome = yield
          raise ActiveRecord::Rollback if outcome.invalid?
        end
        outcome
      end

      def archive_section_and_units
        result = PropertySections::Archive.call(actor: @actor, section: @section)
        return RemovalOutcome.invalid(result.section) if result.invalid?

        @section.units.each do |unit|
          unit_result = Units::Archive.call(actor: @actor, unit: unit)
          return RemovalOutcome.invalid(unit_result.unit) if unit_result.invalid?
        end

        RemovalOutcome.archived(result.section)
      end

      # Units first, so `PropertySection`'s `dependent: :restrict_with_error`
      # on :units never blocks the section destroy once it is empty.
      def soft_delete_section_and_units
        @section.units.each do |unit|
          result = Units::SoftDelete.call(actor: @actor, unit: unit)
          return RemovalOutcome.invalid(result.unit) if result.invalid?
        end

        result = PropertySections::Destroy.call(actor: @actor, section: @section)
        return RemovalOutcome.invalid(result.section) if result.invalid?

        RemovalOutcome.removed(result.section)
      end
    end
  end
end
