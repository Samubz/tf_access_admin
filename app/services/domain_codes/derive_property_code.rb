# frozen_string_literal: true

module DomainCodes
  # Derives a residential property code as `{type_abbrev}-{name_slug}` with an
  # organization-scoped collision suffix (hierarchical-code-generation §Property
  # code). Called on create; never accepts a client-supplied value.
  class DerivePropertyCode
    def self.call(property:)
      new(property: property).call
    end

    def initialize(property:)
      @property = property
    end

    def call
      base = [
        TypeAbbrev.for_property(@property.property_type),
        Slug.call(@property.name)
      ].reject(&:blank?).join("-")

      CollisionResolver.call(base: base) { |candidate| taken?(candidate) }
    end

    private

    # The paranoia default scope already excludes soft-deleted rows; scope to the
    # property's organization explicitly so derivation is correct even outside an
    # ActsAsTenant block.
    def taken?(candidate)
      scope = ResidentialProperty.where(code: candidate)
      scope = scope.where(organization_id: @property.organization_id) if @property.organization_id
      scope = scope.where.not(id: @property.id) if @property.id
      scope.exists?
    end
  end
end
