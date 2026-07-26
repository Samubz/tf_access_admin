# frozen_string_literal: true

module Properties
  module Setup
    # Resolves the recommended +PropertyStructureFormat+ for a +property_type+.
    #
    # Returns +nil+ when the type has no mapped format; callers should then hide
    # quick structure generation and fall back to manual structure creation.
    module StructureFormatResolver
      module_function

      # @return [PropertyStructureFormat, nil]
      def for(property_type:)
        return nil if property_type.blank?

        StructureFormatCatalog.fetch(property_type)
      end
    end
  end
end
