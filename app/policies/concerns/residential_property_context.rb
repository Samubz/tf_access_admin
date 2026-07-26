# frozen_string_literal: true

module ResidentialPropertyContext
  extend ActiveSupport::Concern

  private

  def record_residential_property
    residential_property_from(record)
  end

  def record_unit
    unit_from(record)
  end

  def residential_property_from(resource)
    return nil if resource.blank?
    return resource if resource.is_a?(ResidentialProperty)
    return resource.residential_property if resource.respond_to?(:residential_property) && resource.residential_property.present?

    unit = unit_from(resource)
    return unit.residential_property if unit&.residential_property.present?

    nil
  end

  def unit_from(resource)
    return nil if resource.blank?
    return resource if resource.is_a?(Unit)
    return resource.unit if resource.respond_to?(:unit) && resource.unit.is_a?(Unit)

    nil
  end
end
