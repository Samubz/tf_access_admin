# frozen_string_literal: true

module Properties
  # Creates a residential property within the actor's organization
  # (improve-property-foundation §3.1).
  class Create < Base
    def initialize(actor:, attributes:)
      super(actor: actor)
      @attributes = attributes
    end

    def call
      property = ResidentialProperty.new(descriptive_attributes(@attributes))
      # §3.4: organization comes from trusted tenant context, never from params.
      property.organization = ActsAsTenant.current_tenant
      # Ordinary creation always starts active; lifecycle overrides are not accepted here.
      property.status = PropertyStatuses::ACTIVE
      assign_derived_code!(property)

      authorize!(property, :create?)
      save_property(property)
    end
  end
end
