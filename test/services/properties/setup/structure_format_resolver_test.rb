# frozen_string_literal: true

require "test_helper"

class Properties::Setup::StructureFormatResolverTest < ActiveSupport::TestCase
  def resolve(property_type)
    Properties::Setup::StructureFormatResolver.for(property_type: property_type)
  end

  test "building resolves to tower then floor with units in floor" do
    format = resolve(PropertyTypes::BUILDING)

    assert_equal [ SectionTypes::TOWER, SectionTypes::FLOOR ], format.levels.map { |l| l[:section_type] }
    assert_equal [ :letter, :number ], format.levels.map { |l| l[:suffix_type] }
    assert_equal SectionTypes::FLOOR, format.units_in
  end

  test "tower resolves to a single floor level with units in floor" do
    format = resolve(PropertyTypes::TOWER)

    assert format.single_level?
    assert_equal SectionTypes::FLOOR, format.levels.first[:section_type]
    assert_equal :number, format.levels.first[:suffix_type]
    assert_equal SectionTypes::FLOOR, format.units_in
  end

  test "condominium resolves to sector then block with units in block" do
    format = resolve(PropertyTypes::CONDOMINIUM)

    assert_equal [ SectionTypes::SECTOR, SectionTypes::BLOCK ], format.levels.map { |l| l[:section_type] }
    assert_equal SectionTypes::BLOCK, format.units_in
  end

  test "horizontal_community resolves to sector then block with units in block" do
    format = resolve(PropertyTypes::HORIZONTAL)

    assert_equal [ SectionTypes::SECTOR, SectionTypes::BLOCK ], format.levels.map { |l| l[:section_type] }
    assert_equal SectionTypes::BLOCK, format.units_in
  end

  test "residential_complex resolves to tower then floor with units in floor" do
    format = resolve(PropertyTypes::RESIDENTIAL_COMPLEX)

    assert_equal [ SectionTypes::TOWER, SectionTypes::FLOOR ], format.levels.map { |l| l[:section_type] }
    assert_equal SectionTypes::FLOOR, format.units_in
  end

  test "sector resolves to a single block level with units in block" do
    format = resolve(PropertyTypes::SECTOR)

    assert format.single_level?
    assert_equal SectionTypes::BLOCK, format.levels.first[:section_type]
    assert_equal SectionTypes::BLOCK, format.units_in
  end

  test "mixed_use resolves to tower then floor with units in floor" do
    format = resolve(PropertyTypes::MIXED_USE)

    assert_equal [ SectionTypes::TOWER, SectionTypes::FLOOR ], format.levels.map { |l| l[:section_type] }
    assert_equal SectionTypes::FLOOR, format.units_in
  end

  test "other has no mapped format" do
    assert_nil resolve(PropertyTypes::OTHER)
  end

  test "blank property_type has no mapped format" do
    assert_nil resolve(nil)
    assert_nil resolve("")
  end

  test "every units_in is a unit-eligible section type" do
    Properties::Setup::StructureFormatCatalog.all.each_value do |format|
      assert SectionTypes.eligible_for_units?(format.units_in),
             "expected #{format.units_in} to be unit-eligible"
    end
  end
end
