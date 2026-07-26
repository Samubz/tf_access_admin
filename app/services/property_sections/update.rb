# frozen_string_literal: true

module PropertySections
  # Applies descriptive changes and ordinary active/inactive transitions
  # (improve-property-sections §4.2). Parent moves and archiving go through
  # dedicated services (§4.3/§4.4).
  class Update < Base
    def initialize(actor:, section:, attributes:)
      super(actor: actor)
      @section = section
      @attributes = attributes.to_h.symbolize_keys
    end

    def call
      authorize_manage_sections!(@section.residential_property)

      return Result.invalid(@section) unless reject_inoperative_property!(@section)
      return Result.invalid(@section) if parent_change_requested?

      @section.assign_attributes(descriptive_attributes(@attributes))
      apply_status(@attributes[:status].presence)

      return Result.invalid(@section) if @section.errors.any?

      save_section(@section)
    end

    private

    def parent_change_requested?
      return false unless @attributes.key?(:parent_id)
      return false if @attributes[:parent_id].to_s == @section.parent_id.to_s

      @section.errors.add(:parent_id, :move_requires_service)
      true
    end

    # §4.2: ordinary updates only flip between active and inactive.
    def apply_status(requested_status)
      return if requested_status.nil?

      if requested_status == SectionStatuses::ARCHIVED
        @section.errors.add(:status, :archive_requires_service)
        return
      end

      @section.status = requested_status
    end
  end
end
