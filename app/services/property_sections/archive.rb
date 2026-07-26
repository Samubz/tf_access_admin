# frozen_string_literal: true

module PropertySections
  # Non-destructive archive of a section (improve-property-sections §4.4).
  #
  # Archiving only transitions +status+ to +archived+. It never deletes the
  # record, its children, units, or visits. Descendants remain persisted and
  # become non-operational through effective status. Runs inside a row lock,
  # and is idempotent when the section is already archived (§4.7).
  class Archive < Base
    def initialize(actor:, section:)
      super(actor: actor)
      @section = section
    end

    def call
      authorize_manage_sections!(@section.residential_property)

      return Result.invalid(@section) unless reject_inoperative_property!(@section)
      return Result.noop(@section) if @section.status == SectionStatuses::ARCHIVED

      @section.with_lock do
        @section.update!(status: SectionStatuses::ARCHIVED)
      end

      Result.success(@section)
    rescue ActiveRecord::RecordInvalid
      Result.invalid(@section)
    end
  end
end
