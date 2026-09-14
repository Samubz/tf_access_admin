# frozen_string_literal: true

# Residential property payload for the organization detail endpoints.
# Expects instance option +relationships+ (Api::Private::ResidentRelationships)
# to restrict units and derive isOwner / occupancyType.
class Api::Private::ResidentialPropertySerializer < ActiveModel::Serializer
  attributes :id, :name, :address, :units
  attribute :property_type, key: :propertyType
  attribute :organization_id, key: :organizationId

  def address
    { addressLine: object.address_line, city: object.city, region: object.region }
  end

  def units
    relationships.units.where(residential_property_id: object.id).order(:identifier).map do |unit|
      {
        id: unit.id,
        code: unit.identifier,
        displayName: unit.display_name,
        unitType: unit.unit_type,
        isOwner: relationships.owner?(unit),
        occupancyType: relationships.occupancy_type_for(unit)
      }
    end
  end

  private

  def relationships
    @instance_options[:relationships]
  end
end
