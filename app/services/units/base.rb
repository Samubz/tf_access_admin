# frozen_string_literal: true

module Units
  # Shared boundary for unit lifecycle services (improve-units-foundation §2).
  # Subclasses implement +#call+ and return a {Units::Result}.
  class Base
    # Attributes a descriptive update may set. Organization, property and
    # section are not in this list — they are set from trusted context or via
    # dedicated move/create services (§2.7/§2.12/§2.13).
    DESCRIPTIVE_ATTRIBUTES = %i[identifier display_name unit_type area_m2 metadata].freeze

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:)
      @actor = actor
    end

    private

    attr_reader :actor

    def authorize_manage_units!(property)
      policy = UnitPolicy.new(actor, ::Unit)
      return if policy.allowed?(:manage_units)
      return if policy.property_allowed?(:manage_units, property: property)

      raise Pundit::NotAuthorizedError,
            "not allowed to manage_units for ResidentialProperty #{property.id}"
    end

    include PropertyOperable

    def reject_inoperative_property!(unit)
      return true if property_operable?(unit.residential_property)

      unit.errors.add(:base, :property_not_operative)
      false
    end

    def descriptive_attributes(attributes)
      attributes.to_h.symbolize_keys.slice(*DESCRIPTIVE_ATTRIBUTES)
    end

    def resolve_section(unit, property, section_id)
      id = section_id.presence
      return nil if id.nil?

      section = property.property_sections.find_by(id: id)
      if section.nil?
        unit.errors.add(:property_section_id, t_validation("section_invalid"))
        return :invalid
      end

      section
    end

    def save_unit(unit)
      return Result.success(unit) if unit.save

      Result.invalid(unit)
    rescue ActiveRecord::RecordNotUnique => e
      unit.register_uniqueness_conflict(e)
      Result.conflict(unit)
    end

    def resolve_and_validate_section(unit, section)
      return nil if section.blank?

      if section.deleted_at.present?
        unit.errors.add(:property_section_id, t_validation("section_invalid"))
        return :invalid
      end

      unless section.effectively_active?
        unit.errors.add(:property_section_id, t_validation("section_not_operative"))
        return :invalid
      end

      unless section.can_contain_units?
        unit.errors.add(:property_section_id, t_validation("section_cannot_contain_units"))
        return :invalid
      end

      section
    end

    def t_validation(key)
      I18n.t("frontend.admin.units.validations.#{key}")
    end
  end
end
