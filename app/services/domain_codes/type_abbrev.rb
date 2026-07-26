# frozen_string_literal: true

module DomainCodes
  # Fixed lowercase abbreviations for property and section types used in derived
  # codes (hierarchical-code-generation §Type abbreviations). Stable per catalog
  # value: changing an abbrev would change every future code for that type.
  class TypeAbbrev
    PROPERTY = {
      PropertyTypes::BUILDING            => "bld",
      PropertyTypes::CONDOMINIUM         => "cdo",
      PropertyTypes::HORIZONTAL          => "hor",
      PropertyTypes::RESIDENTIAL_COMPLEX => "clp",
      PropertyTypes::MIXED_USE           => "mix",
      PropertyTypes::TOWER               => "twr",
      PropertyTypes::SECTOR              => "sct",
      PropertyTypes::OTHER               => "oth"
    }.freeze

    SECTION = {
      SectionTypes::BUILDING     => "bld",
      SectionTypes::TOWER        => "tor",
      SectionTypes::FLOOR        => "flo",
      SectionTypes::BLOCK        => "blo",
      SectionTypes::STAGE        => "eta",
      SectionTypes::SECTOR       => "sec",
      SectionTypes::PARKING_AREA => "par",
      SectionTypes::STORAGE_AREA => "sto",
      SectionTypes::OTHER        => "oth"
    }.freeze

    def self.for_property(property_type)
      PROPERTY.fetch(property_type) { fallback(property_type) }
    end

    def self.for_section(section_type)
      SECTION.fetch(section_type) { fallback(section_type) }
    end

    # Legacy or unknown catalog values degrade to a slug of their first three
    # letters rather than raising, keeping derivation total.
    def self.fallback(value)
      Slug.call(value)[0, 3].presence || "sec"
    end
  end
end
