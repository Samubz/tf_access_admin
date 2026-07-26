# frozen_string_literal: true

class Admin::PersonOwnershipRowSerializer < ActiveModel::Serializer
  attributes :id,
    :ownership_percentage,
    :starts_at,
    :ends_at,
    :status,
    :validity_state,
    :residential_property_id,
    :residential_property_name,
    :property_section_id,
    :property_section_name,
    :unit_id,
    :unit_identifier

  delegate :unit, to: :object

  def residential_property_id
    unit.residential_property_id
  end

  def residential_property_name
    unit.residential_property&.name
  end

  def property_section_id
    unit.property_section_id
  end

  def property_section_name
    unit.property_section&.name
  end

  def unit_id
    unit.id
  end

  def unit_identifier
    unit.identifier
  end

  def validity_state
    today = Date.current
    return "finished" if object.ends_at.present? && object.ends_at < today
    return "pending" if object.starts_at.present? && object.starts_at > today
    return "inactive" if object.status != UnitOwnership::STATUS_ACTIVE

    "current"
  end
end
