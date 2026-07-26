# frozen_string_literal: true

module Properties
  module Setup
    # Shared next-action keys for the wizard step 5 completion screen and the
    # property detail page's "Próximos pasos recomendados" section, so both
    # surfaces stay in sync on which follow-up actions a user is authorized for
    # (add-property-detail-view).
    class NextActions
      def self.call(property:, actor:)
        new(property: property, actor: actor).call
      end

      def initialize(property:, actor:)
        @property = property
        @actor = actor
      end

      def call
        return [] unless @property&.persisted?

        policy = ResidentialPropertyPolicy.new(@actor, @property)
        unit_policy = UnitPolicy.new(@actor, Unit)

        actions = []
        actions << "property_detail" if policy.show?
        actions << "reopen_setup" if PropertyStatuses::WIZARD_EDITABLE.include?(@property.status) && policy.update?
        actions << "manage_units" if unit_policy.property_allowed?(:manage_units, property: @property)
        actions << "import_owners"
        actions << "configure_residents"
        actions
      end
    end
  end
end
