# frozen_string_literal: true

# Invitation payload for GET /api/v1/private/invitations (D2).
# Exposes the host's display name only; no document, phone or email of anyone.
# +access_code+ is reserved for a future contract and is always nil.
class Api::Private::InvitationSerializer < ActiveModel::Serializer
  attributes :id, :status, :scheduled_at, :residential_property_name, :unit_identifier, :host_name, :access_code

  def residential_property_name
    object.residential_property&.name
  end

  def unit_identifier
    object.unit&.identifier
  end

  def host_name
    object.created_by&.name
  end

  def access_code
    nil
  end
end
