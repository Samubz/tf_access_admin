# frozen_string_literal: true

module Properties
  module Setup
    # Applies property-identity edits (name, property type, and the other
    # descriptive fields) for a `created`/`configured`/`active` property
    # reopened in the wizard. `normalized_name` regenerates via the model's
    # existing callback. `code` regenerates only when `name` or `property_type`
    # changes, using the same abbreviation+slug convention as
    # `DomainCodes::DerivePropertyCode`, but — unlike that convention, which
    # auto-resolves collisions with a numeric suffix — a collision here is
    # rejected outright so the client can ask the user to change the name
    # (enable-wizard-editing-created-state).
    class UpdateIdentity < Base
      def initialize(actor:, property:, attributes:)
        super(actor: actor)
        @property = property
        @attributes = attributes.to_h.symbolize_keys
      end

      def call
        authorize_setup_property!(@property)

        attrs = descriptive_attributes(@attributes)
        return Result.success(@property) if attrs.blank?

        identity_changed = attrs.key?(:name) && attrs[:name].to_s != @property.name.to_s
        identity_changed ||= attrs.key?(:property_type) && attrs[:property_type].to_s != @property.property_type.to_s

        @property.assign_attributes(attrs)

        if identity_changed
          candidate = derive_candidate_code
          if code_taken?(candidate)
            @property.errors.add(:name, :code_collision)
            return Result.invalid(@property)
          end

          @property.code = candidate
        end

        save_property(@property)
      end

      private

      def derive_candidate_code
        [
          DomainCodes::TypeAbbrev.for_property(@property.property_type),
          DomainCodes::Slug.call(@property.name)
        ].reject(&:blank?).join("-")
      end

      def code_taken?(candidate)
        scope = ResidentialProperty.where(code: candidate, organization_id: @property.organization_id)
        scope = scope.where.not(id: @property.id) if @property.persisted?
        scope.exists?
      end
    end
  end
end
