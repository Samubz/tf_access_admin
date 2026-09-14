# frozen_string_literal: true

# Organization detail for GET /api/v1/private/organization/:id.
# Expects instance option +relationships+ (Api::Private::ResidentRelationships).
class Api::Private::OrganizationSerializer < ActiveModel::Serializer
  attributes :name, :cover, :logo
  attribute :residential_properties, key: :residentialProperties

  def cover
    object.cover_path
  end

  def logo
    object.logo_path
  end

  def residential_properties
    ActiveModelSerializers::SerializableResource.new(
      relationships.residential_properties,
      each_serializer: Api::Private::ResidentialPropertySerializer,
      relationships: relationships
    ).as_json
  end

  private

  def relationships
    @instance_options[:relationships]
  end
end
