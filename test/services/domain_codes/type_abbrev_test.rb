# frozen_string_literal: true

require "test_helper"

class DomainCodes::TypeAbbrevTest < ActiveSupport::TestCase
  test "maps known section types" do
    assert_equal "tor", DomainCodes::TypeAbbrev.for_section(SectionTypes::TOWER)
    assert_equal "flo", DomainCodes::TypeAbbrev.for_section(SectionTypes::FLOOR)
    assert_equal "blo", DomainCodes::TypeAbbrev.for_section(SectionTypes::BLOCK)
  end

  test "maps known property types" do
    assert_equal "clp", DomainCodes::TypeAbbrev.for_property(PropertyTypes::RESIDENTIAL_COMPLEX)
    assert_equal "cdo", DomainCodes::TypeAbbrev.for_property(PropertyTypes::CONDOMINIUM)
  end

  test "every catalog value has an abbreviation" do
    PropertyTypes::ALL.each { |type| assert_match(/\A[a-z0-9]+\z/, DomainCodes::TypeAbbrev.for_property(type)) }
    SectionTypes::ALL.each { |type| assert_match(/\A[a-z0-9]+\z/, DomainCodes::TypeAbbrev.for_section(type)) }
  end

  test "unknown value degrades to a slug fallback" do
    assert_equal "leg", DomainCodes::TypeAbbrev.for_section("legacy")
  end
end
