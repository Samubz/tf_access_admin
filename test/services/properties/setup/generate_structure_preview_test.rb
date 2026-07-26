# frozen_string_literal: true

require "test_helper"

class Properties::Setup::GenerateStructurePreviewTest < ActiveSupport::TestCase
  def resolver(property_type)
    Properties::Setup::StructureFormatResolver.for(property_type: property_type)
  end

  def generate(params:, format: nil, per_page: 10_000)
    Properties::Setup::GenerateStructurePreview.call(params: params, format: format, page: 1, per_page: per_page)
  end

  test "two-level format generates top sections with nested leaf sections" do
    format = resolver(PropertyTypes::BUILDING)
    result = generate(
      format: format,
      params: { level_1_count: 2, level_2_count: 3, level_1_prefix: "Torre", level_2_prefix: "Piso" }
    )

    tops = result[:nodes].select { |n| n[:depth] == 1 }
    leaves = result[:nodes].select { |n| n[:depth] == 2 }

    assert_equal 2, tops.size
    assert_equal 6, leaves.size
    assert_equal [ "Torre A", "Torre B" ], tops.map { |n| n[:name] }
    assert(tops.all? { |n| n[:section_type] == SectionTypes::TOWER })
    assert(leaves.all? { |n| n[:section_type] == SectionTypes::FLOOR })
    assert_equal [ "Piso 1", "Piso 2", "Piso 3" ], leaves.first(3).map { |n| n[:name] }
    assert_equal({ level_1: 2, level_2: 6, sections: 8 }, result[:counts])
  end

  test "single-level format generates only top sections" do
    format = resolver(PropertyTypes::SECTOR)
    result = generate(
      format: format,
      params: { level_1_count: 4, level_1_prefix: "Bloque" }
    )

    assert(result[:nodes].all? { |n| n[:depth] == 1 })
    assert(result[:nodes].all? { |n| n[:section_type] == SectionTypes::BLOCK })
    assert_equal [ "Bloque 1", "Bloque 2", "Bloque 3", "Bloque 4" ], result[:nodes].map { |n| n[:name] }
    assert_equal 0, result[:counts][:level_2]
  end

  test "letter suffix produces letters and number suffix produces numbers" do
    format = resolver(PropertyTypes::RESIDENTIAL_COMPLEX)
    result = generate(
      format: format,
      params: { level_1_count: 3, level_2_count: 1, level_1_prefix: "Torre", level_2_prefix: "Piso" }
    )

    assert_equal [ "Torre A", "Torre B", "Torre C" ], result[:nodes].select { |n| n[:depth] == 1 }.map { |n| n[:name] }
    assert_equal "Piso 1", result[:nodes].find { |n| n[:depth] == 2 }[:name]
  end

  test "building without towers skips the top level" do
    format = resolver(PropertyTypes::BUILDING)
    result = generate(
      format: format,
      params: { skip_top_level: true, level_1_count: 5, level_1_prefix: "Piso" }
    )

    assert(result[:nodes].all? { |n| n[:depth] == 1 })
    assert(result[:nodes].all? { |n| n[:section_type] == SectionTypes::FLOOR })
    assert_equal 5, result[:nodes].size
  end

  test "legacy tower/floor path works without a format" do
    result = generate(
      params: { towers: 2, floors_per_tower: 2, tower_prefix: "Torre", floor_prefix: "Piso" }
    )

    assert_equal 2, result[:nodes].count { |n| n[:depth] == 1 }
    assert_equal 4, result[:nodes].count { |n| n[:depth] == 2 }
    assert_equal SectionTypes::TOWER, result[:nodes].first[:section_type]
  end

  test "pagination slices nodes" do
    format = resolver(PropertyTypes::SECTOR)
    result = Properties::Setup::GenerateStructurePreview.call(
      format: format,
      params: { level_1_count: 10, level_1_prefix: "Bloque" },
      page: 2,
      per_page: 4
    )

    assert_equal 4, result[:nodes].size
    assert_equal 10, result[:pagination][:total]
    assert_equal 3, result[:pagination][:total_pages]
  end
end
