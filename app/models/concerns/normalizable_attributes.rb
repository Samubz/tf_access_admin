module NormalizableAttributes
    extend ActiveSupport::Concern

    class_methods do
      def trims_attributes(*attributes)
        normalizes(*attributes, with: ->(value) { value.strip })
      end

      def normalizes_email(*attributes)
        normalizes(*attributes, with: ->(value) { value.strip.downcase })
      end
    end
end
