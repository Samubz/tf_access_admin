# frozen_string_literal: true

module Properties
  module Setup
    class Confirm < Base
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

        Configure.call(actor: actor, property: @property)
      end
    end
  end
end
