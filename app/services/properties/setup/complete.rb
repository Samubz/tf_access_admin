# frozen_string_literal: true

module Properties
  module Setup
    # Validates step 4 and transitions a draft property to created, leaving it
    # editable through the wizard (enable-wizard-editing-created-state).
    class Complete < Base
      def initialize(actor:, property:)
        super(actor: actor)
        @property = property
      end

      def call
        validation = ValidateStep.new(property: @property, step: 4).call
        unless validation[:valid]
          @property.errors.add(:base, :setup_incomplete)
          return Result.invalid(@property)
        end

        authorize_setup_property!(@property)

        unless @property.status == PropertyStatuses::DRAFT
          @property.errors.add(:status, :invalid_transition)
          return Result.invalid(@property)
        end

        @property.status = PropertyStatuses::CREATED
        WizardState.merge!(@property, current_step: 5, completed_at: Time.current.iso8601)

        save_property(@property)
      end
    end
  end
end
