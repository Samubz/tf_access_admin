# frozen_string_literal: true

module PropertySections
  # Shared boundary for section lifecycle services (improve-property-sections §4).
  # Subclasses implement +#call+ and return a {PropertySections::Result}.
  class Base
    # Descriptive attributes a caller may set. Organization and property are
    # derived from trusted context, never from params (§4.5). +code+ is excluded:
    # it is always system-derived on create and immutable thereafter
    # (hierarchical-code-generation).
    DESCRIPTIVE_ATTRIBUTES = %i[name section_type position metadata].freeze

    # Sentinel for Move when +parent_id+ is intentionally omitted.
    PARENT_UNCHANGED = :parent_unchanged

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:)
      @actor = actor
    end

    private

    attr_reader :actor

    def authorize_manage_sections!(property)
      policy = PropertySectionPolicy.new(actor, PropertySection)
      return if policy.allowed?(:manage_sections)
      return if policy.property_allowed?(:manage_sections, property: property)

      raise Pundit::NotAuthorizedError,
            "not allowed to manage_sections for ResidentialProperty #{property.id}"
    end

    include PropertyOperable

    def reject_inoperative_property!(section)
      return true if property_operable?(section.residential_property)

      section.errors.add(:base, :property_not_operative)
      false
    end

    def descriptive_attributes(attributes)
      attributes.to_h.symbolize_keys.slice(*DESCRIPTIVE_ATTRIBUTES)
    end

    # System-derived code from hierarchy + type + name; overwrites any client
    # value (hierarchical-code-generation). Requires organization, property,
    # section_type, name, and parent (if any) to be assigned first.
    def assign_derived_code!(section)
      section.code = DomainCodes::DeriveSectionCode.call(section: section)
    end

    def save_section(section)
      return Result.success(section) if section.save

      Result.invalid(section)
    rescue ActiveRecord::RecordNotUnique => e
      section.register_uniqueness_conflict(e)
      Result.invalid(section)
    end

    def assign_organization_from_property!(section, property)
      section.organization = property.organization
      section.residential_property = property
    end

    # Assigns the parent for a create-style operation within the trusted
    # organization/property context. A blank +parent_id+ means a root section; a
    # present-but-unresolvable +parent_id+ (missing, cross-property or
    # cross-organization, since it is looked up inside the property scope) is a
    # structured domain error on +parent_id+ — never a silent root
    # (improve-property-sections §3). Returns +true+ when the section is ready to
    # validate, +false+ when an invalid parent was requested.
    def assign_parent_for_create(section, property, parent: nil, parent_id: nil)
      if parent.present?
        section.parent = parent
        return true
      end

      identifier = parent_id.presence
      return true if identifier.nil?

      resolved = property.property_sections.find_by(id: identifier)
      if resolved.nil?
        section.errors.add(
          :parent_id, :parent_invalid,
          message: I18n.t("frontend.admin.property_sections.validations.parent_invalid")
        )
        return false
      end

      section.parent = resolved
      true
    end
  end
end
