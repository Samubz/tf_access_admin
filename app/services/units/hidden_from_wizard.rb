# frozen_string_literal: true

module Units
  # Whether a unit's effective status (its own status, or its section's
  # `effective_status`) is archived — such units must not appear in the wizard
  # (enable-wizard-editing-created-state). This is specific to the wizard; it
  # does not change how archived units are shown in ordinary, non-wizard unit
  # administration.
  class HiddenFromWizard
    def self.call(unit)
      return true if unit.status == UnitStatuses::ARCHIVED

      unit.property_section.present? && unit.property_section.effective_status == SectionStatuses::ARCHIVED
    end
  end
end
