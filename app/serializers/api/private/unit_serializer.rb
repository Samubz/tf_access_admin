# frozen_string_literal: true

# Unit payload for GET /api/v1/private/units.
class Api::Private::UnitSerializer < ActiveModel::Serializer
  attributes :id, :name, :organization

  def name
    object.display_name.presence || object.identifier
  end

  def organization
    { id: object.organization.id, name: object.organization.name }
  end
end
