# frozen_string_literal: true

module Authorization
  class Resolver
    attr_reader :user, :organization, :property, :unit, :record, :profile

    def initialize(user:, organization:, property: nil, unit: nil, record: nil, profile: nil)
      @user = user
      @organization = organization
      @property = property
      @unit = unit
      @record = record
      @profile = profile || GrantProfile.build(user, organization)
      @evaluation_cache = {}
    end

    def allowed?(capability)
      capability = Capabilities.normalize(capability)
      return false unless Capabilities.known?(capability)

      cache_key = [ capability, resolved_property&.id, resolved_unit&.id, record&.id ]
      @evaluation_cache[cache_key] ||= evaluate_allowed?(capability)
    end

    def can?(capability, resource = nil)
      return allowed?(capability) if resource.nil?

      contextual = with_context(
        property: extract_property(resource) || property,
        unit: extract_unit(resource) || unit,
        record: resource
      )
      contextual.allowed?(capability)
    end

    def with_context(property: self.property, unit: self.unit, record: self.record)
      return self if same_context?(property, unit, record)

      self.class.new(
        user: user,
        organization: organization,
        property: property,
        unit: unit,
        record: record,
        profile: profile
      )
    end

    def accessible_property_ids
      PropertyScope.new(self).accessible_property_ids
    end

    def property_accessible?(target_property)
      return false if target_property.blank?
      return false unless same_organization?(target_property)

      accessible_property_ids.include?(target_property.id)
    end

    private

    def evaluate_allowed?(capability)
      return false unless profile.member_of_organization?
      return false if cross_organization_context?

      return true if profile.organization_capabilities.include?(capability)

      property_id = resolved_property&.id
      if property_id
        caps = profile.property_capabilities[property_id]
        return true if caps&.include?(capability)
      end

      unit_id = resolved_unit&.id
      if unit_id
        unit_caps = profile.unit_capabilities[unit_id]
        return true if unit_caps&.include?(capability)

        unit_property_id = resolved_unit.residential_property_id
        if unit_property_id
          property_caps = profile.property_capabilities[unit_property_id]
          return true if property_caps&.include?(capability)
        end
      end

      false
    end

    def resolved_property
      @resolved_property ||= begin
        candidate = property || extract_property(record) || extract_property(unit)
        candidate if candidate.is_a?(ResidentialProperty) && same_organization?(candidate)
      end
    end

    def resolved_unit
      @resolved_unit ||= begin
        candidate = unit || extract_unit(record)
        candidate if candidate.is_a?(Unit) && same_organization?(candidate)
      end
    end

    def extract_property(resource)
      return resource if resource.is_a?(ResidentialProperty)
      return resource.residential_property if resource.respond_to?(:residential_property) && resource.residential_property.present?
      return resource.unit.residential_property if resource.respond_to?(:unit) && resource.unit.present?

      nil
    end

    def extract_unit(resource)
      return resource if resource.is_a?(Unit)
      return resource.unit if resource.respond_to?(:unit) && resource.unit.is_a?(Unit)

      nil
    end

    def same_organization?(resource)
      resource.respond_to?(:organization_id) && resource.organization_id == organization.id
    end

    def same_context?(property, unit, record)
      self.property == property && self.unit == unit && self.record == record
    end

    def cross_organization_context?
      return true if property.present? && !same_organization?(property)
      return true if unit.present? && !same_organization?(unit)
      return true if record.present? && record.respond_to?(:organization_id) && !same_organization?(record)

      false
    end
  end
end
