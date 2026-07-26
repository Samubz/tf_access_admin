# frozen_string_literal: true

module Properties
  module Setup
    class Base < Properties::Base
      SETUP_ATTRIBUTES = %i[
        structure_mode units_mode
        quick_structure quick_structure_confirmed
      ].freeze

      private

      def authorize_setup!
        policy = ResidentialPropertyPolicy.new(actor, ResidentialProperty.new)
        return if policy.create?

        raise Pundit::NotAuthorizedError, "not allowed to start property setup"
      end

      def authorize_setup_property!(property)
        authorize!(property, :update?)
      end

      def strip_untrusted!(attributes)
        attrs = attributes.to_h.symbolize_keys
        attrs.except(:organization_id, :residential_property_id)
      end

      def merge_setup_metadata!(property, attributes)
        attrs = strip_untrusted!(attributes)
        setup_attrs = {
          structure_mode: attrs[:structure_mode],
          units_mode: attrs[:units_mode],
          quick_structure: attrs[:quick_structure],
          quick_structure_confirmed: attrs[:quick_structure_confirmed]
        }.compact

        WizardState.merge!(property, setup_attrs) if setup_attrs.any?
      end

      def address_present?(property)
        property.address_line.present? || property.city.present?
      end
    end
  end
end
