# frozen_string_literal: true

module Properties
  module Setup
    # Detects and, once confirmed, applies a destructive structure reset when
    # a wizard edit changes property type or structure mode on a property that
    # already has sections or units (enable-wizard-editing-created-state).
    #
    # `draft` properties are hard-destroyed (no operational history is possible
    # yet). `created`/`configured`/`active` properties go through the same
    # operational-history-aware soft-delete/archive rule as a single manual
    # removal (`RemoveSection`/`RemoveUnit`), applied to every section and unit,
    # all-or-nothing.
    class ResetStructure
      def self.call(...) = new(...).call

      def initialize(actor:, property:, new_property_type: nil, new_structure_mode: nil, confirmed: false)
        @actor = actor
        @property = property
        @new_property_type = new_property_type
        @new_structure_mode = new_structure_mode
        @confirmed = confirmed
      end

      def call
        return RemovalOutcome.removed(@property) unless reset_needed?
        return RemovalOutcome.needs_confirmation(@property) unless @confirmed

        if @property.status == PropertyStatuses::DRAFT
          destroy_all!
        else
          remove_all!
        end
      end

      private

      def reset_needed?
        return false unless has_existing_structure?

        type_changed? || structure_mode_changed?
      end

      def has_existing_structure?
        @property.property_sections.exists? || @property.units.exists?
      end

      def type_changed?
        @new_property_type.present? && @new_property_type.to_s != @property.property_type.to_s
      end

      def structure_mode_changed?
        return false if @new_structure_mode.blank?

        @new_structure_mode.to_s != WizardState.structure_mode(@property).to_s
      end

      def destroy_all!
        ActiveRecord::Base.transaction do
          # `Unit#destroy`/`destroy_fully!` is guarded by a `before_destroy`
          # callback that only `Units::SoftDelete` normally satisfies; a
          # from-scratch draft reset bypasses that service, so it must
          # authorize the hard destroy explicitly.
          @property.units.each { |unit| unit.authorize_soft_delete!.destroy_fully! }
          ordered_sections.each(&:destroy_fully!)
        end
        RemovalOutcome.removed(@property)
      end

      def remove_all!
        outcome = RemovalOutcome.removed(@property)

        ActiveRecord::Base.transaction do
          unsectioned_units.each do |unit|
            unit_outcome = RemoveUnit.call(actor: @actor, unit: unit, confirmed: true)
            next if unit_outcome.success?

            outcome = unit_outcome
            raise ActiveRecord::Rollback
          end

          ordered_sections.each do |section|
            section_outcome = RemoveSection.call(actor: @actor, section: section, confirmed: true)
            next if section_outcome.success?

            outcome = section_outcome
            raise ActiveRecord::Rollback
          end
        end

        outcome
      end

      # Children before roots, so `PropertySection`'s `dependent:
      # :restrict_with_error` on :children never blocks (each section is empty
      # of children by the time it is destroyed/archived).
      def ordered_sections
        @property.property_sections.to_a.sort_by { |section| section.parent_id.present? ? 0 : 1 }
      end

      def unsectioned_units
        @property.units.where(property_section_id: nil)
      end
    end
  end
end
