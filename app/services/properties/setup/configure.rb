# frozen_string_literal: true

module Properties
  module Setup
    # Transitions a property from draft or created to configured after wizard confirmation.
    class Configure < Base
      TRANSITIONABLE_FROM = [ PropertyStatuses::DRAFT, PropertyStatuses::CREATED ].freeze

      def initialize(actor:, property:)
        super(actor: actor)
        @property = property
      end

      def call
        authorize_setup_property!(@property)

        unless TRANSITIONABLE_FROM.include?(@property.status)
          @property.errors.add(:status, :invalid_transition)
          return Result.invalid(@property)
        end

        @property.status = PropertyStatuses::CONFIGURED
        WizardState.merge!(@property, current_step: 5, confirmed_at: Time.current.iso8601)

        save_property(@property)
      end
    end
  end
end
