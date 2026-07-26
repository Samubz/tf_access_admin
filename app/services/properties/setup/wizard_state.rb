# frozen_string_literal: true

module Properties
  module Setup
    # Reads and writes wizard progress on +ResidentialProperty#metadata+.
    module WizardState
      METADATA_KEY = "setup_wizard"

      module_function

      def read(property)
        return {}.with_indifferent_access if property.nil?

        property.metadata.fetch(METADATA_KEY, {}).with_indifferent_access
      end

      def merge!(property, attrs)
        current = read(property).to_h
        property.metadata = property.metadata.merge(
          METADATA_KEY => current.merge(attrs.stringify_keys)
        )
      end

      def current_step(property)
        step = read(property)[:current_step]
        step.present? ? step.to_i : 1
      end

      def structure_mode(property)
        read(property)[:structure_mode].presence
      end

      def units_mode(property)
        read(property)[:units_mode].presence
      end
    end
  end
end
