# frozen_string_literal: true

# Shared operability check for properties that admit section/unit mutations
# (improve-property-setup-flow).
module PropertyOperable
  extend ActiveSupport::Concern

  def property_operable?(property)
    PropertyStatuses::OPERABLE.include?(property.status)
  end
end
