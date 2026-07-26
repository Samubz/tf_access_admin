# frozen_string_literal: true

# Allowed +units.unit_type+ values (string-backed).
#
# +CANONICAL+ is the target catalog every new write must use
# (improve-units-foundation §1.16). +LEGACY+ values may still exist in older data
# and are tolerated transitorily (§1.15) — they are excluded from +CANONICAL+ so
# new records and +unit_type+ changes are forced onto the canonical catalog, but
# kept in +ALL+ so an unrelated update of a legacy row is not blocked. The final
# database check constraint and the legacy→canonical mapping are deferred to the
# migration/audit work (Open Question #1).
module UnitTypes
  # Canonical catalog.
  APARTMENT       = "apartment"
  HOUSE           = "house"
  OFFICE          = "office"
  COMMERCIAL_UNIT = "commercial_unit"
  PARKING_SPACE   = "parking_space"
  STORAGE_ROOM    = "storage_room"
  COMMON_AREA     = "common_area"
  OTHER           = "other"

  # Legacy values pending an audited mapping; not eligible for new writes.
  STUDIO     = "studio"
  DUPLEX     = "duplex"
  PENTHOUSE  = "penthouse"
  PARKING    = "parking"
  STORAGE    = "storage"
  COMMERCIAL = "commercial"
  WAREHOUSE  = "warehouse"

  CANONICAL = [
    APARTMENT,
    HOUSE,
    OFFICE,
    COMMERCIAL_UNIT,
    PARKING_SPACE,
    STORAGE_ROOM,
    COMMON_AREA,
    OTHER
  ].freeze

  LEGACY = [
    STUDIO,
    DUPLEX,
    PENTHOUSE,
    PARKING,
    STORAGE,
    COMMERCIAL,
    WAREHOUSE
  ].freeze

  # Every tolerated value (canonical + legacy). Used where existing data must be
  # accepted; new writes are restricted to +CANONICAL+ by the model.
  ALL = (CANONICAL + LEGACY).freeze
end
