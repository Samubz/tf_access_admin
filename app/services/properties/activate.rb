# frozen_string_literal: true

module Properties
  # Activates a configured property (improve-property-setup-flow).
  class Activate < Base
    def initialize(actor:, property:)
      super(actor: actor)
      @property = property
    end

    def call
      authorize!(@property, :update?)

      unless @property.status == PropertyStatuses::CONFIGURED
        @property.errors.add(:status, :invalid_transition)
        return Result.invalid(@property)
      end

      @property.status = PropertyStatuses::ACTIVE
      save_property(@property)
    end
  end
end
