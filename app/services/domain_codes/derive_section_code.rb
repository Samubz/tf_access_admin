# frozen_string_literal: true

module DomainCodes
  # Derives a property section code (hierarchical-code-generation §Section code).
  #
  #   root:  {property_code}-{section_type_abbrev}-{name_slug}
  #   child: {parent_code}-{name_slug}
  #
  # Reads the parent/property code in memory, so it works mid-batch before those
  # records are reloaded. Collision scope matches the section unique index:
  # (organization, residential_property, parent_id, section_type, code).
  class DeriveSectionCode
    def self.call(section:)
      new(section: section).call
    end

    def initialize(section:)
      @section = section
    end

    def call
      CollisionResolver.call(base: base) { |candidate| taken?(candidate) }
    end

    private

    def base
      if @section.parent
        "#{@section.parent.code}-#{Slug.call(@section.name)}"
      else
        [
          @section.residential_property&.code,
          TypeAbbrev.for_section(@section.section_type),
          Slug.call(@section.name)
        ].reject(&:blank?).join("-")
      end
    end

    def taken?(candidate)
      scope = PropertySection.where(
        organization_id: @section.organization_id,
        residential_property_id: @section.residential_property_id,
        parent_id: @section.parent_id,
        section_type: @section.section_type,
        code: candidate
      )
      scope = scope.where.not(id: @section.id) if @section.id
      scope.exists?
    end
  end
end
