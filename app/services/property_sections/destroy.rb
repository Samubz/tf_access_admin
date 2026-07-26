# frozen_string_literal: true

module PropertySections
  # Soft delete of a section for an operable (draft/created/configured/active)
  # property (wizard-manual-structure-builder, enable-wizard-editing-created-state).
  #
  # Unlike {Archive} (which only flips status and keeps the node in the tree),
  # +Destroy+ removes the section from the default scope via paranoia
  # (+acts_as_paranoid+, +section.destroy+) so a mistaken section disappears from
  # the live builder preview. Children/units are +dependent: :restrict_with_error+,
  # so a section with dependents fails cleanly and the error is surfaced — callers
  # that need to remove a whole subtree (see {Properties::Setup::RemoveSection})
  # must clear units/children first. Idempotent when the section is already
  # soft-deleted.
  class Destroy < Base
    def initialize(actor:, section:)
      super(actor: actor)
      @section = section
    end

    def call
      authorize_manage_sections!(@section.residential_property)

      return Result.noop(@section) if @section.deleted_at.present?
      return Result.invalid(@section) unless reject_inoperative_property!(@section)

      @section.with_lock do
        return Result.invalid(@section) unless @section.destroy
      end

      Result.success(@section)
    end
  end
end
