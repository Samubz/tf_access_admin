# frozen_string_literal: true

module PropertySections
  # Moves a section within the same property while preserving its subtree
  # (improve-property-sections §4.3).
  class Move < Base
    def initialize(actor:, section:, parent_id: PARENT_UNCHANGED, position: nil)
      super(actor: actor)
      @section = section
      @parent_id = parent_id
      @position = position
    end

    def call
      authorize_manage_sections!(@section.residential_property)

      return Result.invalid(@section) unless reject_inoperative_property!(@section)

      @section.with_lock do
        apply_parent_change
        @section.position = @position if @position.present?

        save_section(@section)
      end
    end

    private

    def apply_parent_change
      return if @parent_id == PARENT_UNCHANGED

      @section.parent_id = @parent_id.presence
    end
  end
end
