# frozen_string_literal: true

# Allowed +property_sections.status+ values (string-backed lifecycle).
#
# - +active+:   operable section when its whole ancestor chain is active.
# - +inactive+: reversible suspension.
# - +archived+: non-destructive, terminal retirement within this change.
module SectionStatuses
  ACTIVE   = "active"
  INACTIVE = "inactive"
  ARCHIVED = "archived"

  ALL = [
    ACTIVE,
    INACTIVE,
    ARCHIVED
  ].freeze
end
