# frozen_string_literal: true

# Allowed +property_sections.section_type+ values (string-backed).
#
# +section_type+ describes the structural function of a section; it does not
# grant permissions. Only +block+, +tower+ and +floor+ are eligible to contain
# units (improve-property-sections §2.8); the concrete enforcement lives in the
# future Unit change.
module SectionTypes
  BUILDING     = "building"
  TOWER        = "tower"
  FLOOR        = "floor"
  BLOCK        = "block"
  STAGE        = "stage"
  SECTOR       = "sector"
  PARKING_AREA = "parking_area"
  STORAGE_AREA = "storage_area"
  OTHER        = "other"

  ALL = [
    BUILDING,
    TOWER,
    FLOOR,
    BLOCK,
    STAGE,
    SECTOR,
    PARKING_AREA,
    STORAGE_AREA,
    OTHER
  ].freeze

  # Section types eligible to directly contain units (§2.8).
  UNIT_ELIGIBLE = [ BLOCK, TOWER, FLOOR ].freeze

  # Legacy values that may exist in older data. They are intentionally excluded
  # from +ALL+ (and therefore from the inclusion validation) so new records use
  # the canonical catalog. Mapping legacy → canonical is deferred (Open Q #2) and
  # the DB check constraint still tolerates them for existing rows.
  PARKING    = "parking"
  STORAGE    = "storage"
  COMMERCIAL = "commercial"
  AMENITIES  = "amenities"
  ENTRANCE   = "entrance"
  GARDEN     = "garden"

  module_function

  # Whether a +section_type+ string is eligible to contain units.
  def eligible_for_units?(section_type)
    UNIT_ELIGIBLE.include?(section_type)
  end
end
