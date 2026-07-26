# frozen_string_literal: true

module PropertySections
  # Creates a section within an authorized property (improve-property-sections §4.1).
  class Create < Base
    def initialize(actor:, property:, parent: nil, attributes: {})
      super(actor: actor)
      @property = property
      @parent = parent
      @attributes = attributes
    end

    def call
      authorize_manage_sections!(@property)

      section = PropertySection.new(descriptive_attributes(@attributes))
      assign_organization_from_property!(section, @property)

      # A requested-but-invalid parent must fail loudly, never collapse into a
      # root section (improve-property-sections §3).
      return Result.invalid(section) unless assign_parent_for_create(
        section, @property, parent: @parent, parent_id: @attributes[:parent_id]
      )

      # Ordinary creation always starts active; lifecycle overrides are not accepted here.
      section.status = SectionStatuses::ACTIVE

      return Result.invalid(section) unless reject_inoperative_property!(section)

      assign_derived_code!(section)
      save_section(section)
    end
  end
end
