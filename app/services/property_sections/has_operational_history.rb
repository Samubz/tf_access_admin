# frozen_string_literal: true

module PropertySections
  # Whether any of a section's own units has operational history that must
  # not be silently soft-deleted (enable-wizard-editing-created-state). Scoped
  # to the section's own units only: a section with child sections cannot be
  # removed as a single unit anyway (`dependent: :restrict_with_error` blocks
  # it until the children are removed individually), so there is nothing to
  # check transitively here.
  class HasOperationalHistory
    def self.call(section)
      section.units.any? { |unit| Units::HasOperationalHistory.call(unit) }
    end
  end
end
