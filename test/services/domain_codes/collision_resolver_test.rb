# frozen_string_literal: true

require "test_helper"

class DomainCodes::CollisionResolverTest < ActiveSupport::TestCase
  test "returns the base when it is free" do
    result = DomainCodes::CollisionResolver.call(base: "cdo-tor-torre-a") { |_c| false }
    assert_equal "cdo-tor-torre-a", result
  end

  test "appends -2 when the base is taken" do
    taken = [ "cdo-tor-torre-a" ]
    result = DomainCodes::CollisionResolver.call(base: "cdo-tor-torre-a") { |c| taken.include?(c) }
    assert_equal "cdo-tor-torre-a-2", result
  end

  test "advances the suffix until a free code is found" do
    taken = [ "base", "base-2", "base-3" ]
    result = DomainCodes::CollisionResolver.call(base: "base") { |c| taken.include?(c) }
    assert_equal "base-4", result
  end
end
