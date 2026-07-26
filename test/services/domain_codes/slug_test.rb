# frozen_string_literal: true

require "test_helper"

class DomainCodes::SlugTest < ActiveSupport::TestCase
  test "transliterates accents to ascii" do
    assert_equal "torre-a", DomainCodes::Slug.call("Torre Á")
    assert_equal "area-4", DomainCodes::Slug.call("Área 4")
  end

  test "slugs a non-sequential label literally" do
    assert_equal "torre-123", DomainCodes::Slug.call("Torre 123")
  end

  test "downcases and hyphenates whitespace" do
    assert_equal "piso-norte-1", DomainCodes::Slug.call("  Piso   Norte 1 ")
  end

  test "drops characters outside the alphanumeric-hyphen set" do
    assert_equal "torre-a-b", DomainCodes::Slug.call("Torre A/B!")
  end

  test "caps segment length and strips a trailing hyphen" do
    result = DomainCodes::Slug.call("a" * 40, max_length: 10)
    assert_equal 10, result.length

    capped = DomainCodes::Slug.call("abcdefghi jkl", max_length: 10)
    assert_equal "abcdefghi", capped
  end

  test "blank input yields an empty slug" do
    assert_equal "", DomainCodes::Slug.call("")
    assert_equal "", DomainCodes::Slug.call(nil)
  end
end
