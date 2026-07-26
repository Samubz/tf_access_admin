# frozen_string_literal: true

# Allowed +residential_properties.status+ values (string-backed lifecycle).
#
# - +draft+:      Wizard initiated; configuration in progress.
# - +created+:    Wizard completed but still editable through the wizard.
# - +configured+: Wizard confirmed; pending explicit activation.
# - +active+:     Operational property that admits normal management.
# - +inactive+:   Temporarily suspended, reversible.
# - +archived+:   Retired property, preserved for history (terminal).
module PropertyStatuses
  DRAFT      = "draft"
  CREATED    = "created"
  CONFIGURED = "configured"
  ACTIVE     = "active"
  INACTIVE   = "inactive"
  ARCHIVED   = "archived"

  # Statuses that allow section/unit mutations.
  OPERABLE = [ DRAFT, CREATED, CONFIGURED, ACTIVE ].freeze

  # Statuses introduced by the setup wizard.
  SETUP = [ DRAFT, CREATED, CONFIGURED ].freeze

  # Statuses the setup wizard may reopen for editing (enable-wizard-editing-created-state).
  WIZARD_EDITABLE = [ CREATED, CONFIGURED, ACTIVE ].freeze

  # Statuses where the property detail page shows the primary edit action,
  # opening the setup wizard (add-property-detail-view).
  DETAIL_EDITABLE = [ DRAFT, CREATED ].freeze

  ALL = [
    DRAFT,
    CREATED,
    CONFIGURED,
    ACTIVE,
    INACTIVE,
    ARCHIVED
  ].freeze
end
