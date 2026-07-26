# frozen_string_literal: true

# Allowed +units.status+ values (string-backed lifecycle).
#
# - +available+:   unit ready, no operational occupancy assumed by this change.
# - +occupied+:    administratively occupied (not auto-derived from occupancies).
# - +inactive+:    temporarily non-operational.
# - +maintenance+: out of service for maintenance.
# - +archived+:    non-destructive business retirement (set only by Units::Archive).
module UnitStatuses
  AVAILABLE   = "available"
  OCCUPIED    = "occupied"
  INACTIVE    = "inactive"
  MAINTENANCE = "maintenance"
  ARCHIVED    = "archived"

  ALL = [
    AVAILABLE,
    OCCUPIED,
    INACTIVE,
    MAINTENANCE,
    ARCHIVED
  ].freeze

  # Operational statuses an ordinary descriptive update may move between
  # (improve-units-foundation §2.15). +archived+ is reserved for Units::Archive.
  OPERATIONAL = [
    AVAILABLE,
    OCCUPIED,
    INACTIVE,
    MAINTENANCE
  ].freeze
end
