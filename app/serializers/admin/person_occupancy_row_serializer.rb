# frozen_string_literal: true

class Admin::PersonOccupancyRowSerializer < ActiveModel::Serializer
  attributes :id,
    :occupancy_type,
    :occupancy_type_label,
    :starts_at,
    :ends_at,
    :status,
    :status_label,
    :validity_state,
    :residential_property_id,
    :residential_property_name,
    :property_section_id,
    :property_section_name,
    :unit_id,
    :unit_identifier

  delegate :unit, to: :object

  def occupancy_type_label
    I18n.t(
      "frontend.admin.unit_occupancies.occupancy_types.#{object.occupancy_type}",
      default: object.occupancy_type.to_s.humanize
    )
  end

  def status_label
    I18n.t(
      "frontend.admin.units.show.occupants.statuses.#{object.status}",
      default: object.status.to_s.humanize
    )
  end

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
    now = Time.zone.now
    day_start = now.beginning_of_day
    day_end = now.end_of_day

    return "finished" if object.ends_at.present? && object.ends_at < day_start
    return "pending" if object.starts_at.present? && object.starts_at > day_end
    return "inactive" if object.status != OccupancyStatuses::ACTIVE

    "current"
  end
end
