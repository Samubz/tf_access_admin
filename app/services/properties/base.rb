# frozen_string_literal: true

module Properties
  # Shared boundary for the property lifecycle services
  # (improve-property-foundation §3). Subclasses implement +#call+ and return a
  # {Properties::Result}.
  #
  # == Input contract
  #   actor: User — operator performing the action; authorization re-runs here so
  #                 hiding UI never substitutes for policy enforcement.
  #
  # Normalization lives in the model (§2); these services own the lifecycle:
  # trusted organization derivation, status transitions, and the delete/archive
  # distinction (§3.5).
  class Base
    # Descriptive (non-lifecycle, non-tenant) attributes a caller may set. The
    # organization is derived from trusted context, never from params (§3.4/§2.7).
    DESCRIPTIVE_ATTRIBUTES = %i[
      name code property_type address_line city region country timezone metadata
    ].freeze

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:)
      @actor = actor
    end

    private

    attr_reader :actor

    def authorize!(property, query)
      policy = ResidentialPropertyPolicy.new(actor, property)
      return if policy.public_send(query)

      raise Pundit::NotAuthorizedError, "not allowed to #{query} this ResidentialProperty"
    end

    def descriptive_attributes(attributes)
      attributes.to_h.symbolize_keys.slice(*DESCRIPTIVE_ATTRIBUTES)
    end

    # System-derived code from hierarchy + type + name; overwrites any client
    # value (hierarchical-code-generation). Requires organization to be set.
    def assign_derived_code!(property)
      property.code = DomainCodes::DerivePropertyCode.call(property: property)
    end

    # Persists and maps a concurrent unique-violation to a field error (§2.8)
    # so the caller still receives a structured invalid result instead of a 500.
    def save_property(property)
      return Result.success(property) if property.save

      Result.invalid(property)
    rescue ActiveRecord::RecordNotUnique => e
      property.register_uniqueness_conflict(e)
      Result.invalid(property)
    end
  end
end
