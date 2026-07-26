# frozen_string_literal: true

require "test_helper"

class AccentInsensitiveMatchTest < ActiveSupport::TestCase
  test "where_clause builds an OR condition across unaccented columns" do
    clause = AccentInsensitiveMatch.where_clause("units.identifier", "units.display_name")

    assert_equal "unaccent(units.identifier) ILIKE unaccent(:term) OR unaccent(units.display_name) ILIKE unaccent(:term)", clause
  end

  test "term wraps and sanitizes the search value for LIKE" do
    assert_equal "%region%", AccentInsensitiveMatch.term("  region  ")
    assert_equal "%50\\%%", AccentInsensitiveMatch.term("50%")
  end
end
