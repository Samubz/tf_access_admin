# frozen_string_literal: true

module Properties
  module Setup
    # Declarative catalog of recommended structure formats per +property_type+.
    #
    # Each format defines up to 2 section levels and the leaf level (+units_in+)
    # where units live. Property types not present here (e.g. +other+) have no
    # recommended format: quick structure generation is not offered for them and
    # the user must build the structure manually.
    module StructureFormatCatalog
      module_function

      # @return [Hash{String => PropertyStructureFormat}]
      def all
        @all ||= {
          PropertyTypes::BUILDING => format(
            [ level(SectionTypes::TOWER, :letter), level(SectionTypes::FLOOR, :number) ],
            SectionTypes::FLOOR
          ),
          PropertyTypes::TOWER => format(
            [ level(SectionTypes::FLOOR, :number) ],
            SectionTypes::FLOOR
          ),
          PropertyTypes::CONDOMINIUM => format(
            [ level(SectionTypes::SECTOR, :number), level(SectionTypes::BLOCK, :number) ],
            SectionTypes::BLOCK
          ),
          PropertyTypes::HORIZONTAL => format(
            [ level(SectionTypes::SECTOR, :number), level(SectionTypes::BLOCK, :number) ],
            SectionTypes::BLOCK
          ),
          PropertyTypes::RESIDENTIAL_COMPLEX => format(
            [ level(SectionTypes::TOWER, :letter), level(SectionTypes::FLOOR, :number) ],
            SectionTypes::FLOOR
          ),
          PropertyTypes::SECTOR => format(
            [ level(SectionTypes::BLOCK, :number) ],
            SectionTypes::BLOCK
          ),
          PropertyTypes::MIXED_USE => format(
            [ level(SectionTypes::TOWER, :letter), level(SectionTypes::FLOOR, :number) ],
            SectionTypes::FLOOR
          )
        }.freeze
      end

      # @return [PropertyStructureFormat, nil]
      def fetch(property_type)
        all[property_type.to_s]
      end

      def format(levels, units_in)
        PropertyStructureFormat.new(levels: levels, units_in: units_in)
      end

      def level(section_type, suffix_type)
        {
          section_type: section_type,
          label_key: "admin.property_setup.structure_formats.section_types.#{section_type}",
          suffix_type: suffix_type
        }
      end
    end
  end
end
