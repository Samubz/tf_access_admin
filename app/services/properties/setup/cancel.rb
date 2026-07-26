# frozen_string_literal: true

module Properties
  module Setup
    class Cancel < Base
      def initialize(actor:, property:, delete_draft: false)
        super(actor: actor)
        @property = property
        @delete_draft = delete_draft
      end

      def call
        authorize_setup_property!(@property)

        case @property.status
        when PropertyStatuses::DRAFT
          return Result.success(@property) unless @delete_draft

          @property.destroy!
          Result.success(@property)
        when PropertyStatuses::CONFIGURED, PropertyStatuses::ACTIVE
          Result.noop(@property)
        else
          @property.errors.add(:status, :invalid_transition)
          Result.invalid(@property)
        end
      end
    end
  end
end
