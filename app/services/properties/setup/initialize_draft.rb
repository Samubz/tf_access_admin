# frozen_string_literal: true

module Properties
  module Setup
    # Persists step 1 data as a draft property (improve-property-setup-flow).
    class InitializeDraft < Base
      def initialize(actor:, attributes:)
        super(actor: actor)
        @attributes = attributes
      end

      def call
        authorize_setup!

        property = ResidentialProperty.new(descriptive_attributes(@attributes))
        property.organization = ActsAsTenant.current_tenant
        property.status = PropertyStatuses::DRAFT
        assign_derived_code!(property)
        merge_setup_metadata!(property, @attributes)
        WizardState.merge!(property, current_step: 2)

        save_property(property)
      end
    end
  end
end
