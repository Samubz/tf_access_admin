# frozen_string_literal: true

require "test_helper"

class Units::SearchTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @property = create_property(@organization, "Search Property")
    @unit = create_unit(@property, "Torre A 101")
    @unit.update!(display_name: "Penthouse View")
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "matches normalized identifier from equivalent input" do
    results = Units::Search.apply(Unit.all, term: "  torre a 101 ")

    assert_includes results, @unit
  end

  test "matches display name case-insensitively" do
    results = Units::Search.apply(Unit.all, term: "penthouse")

    assert_includes results, @unit
  end

  test "matches display name accent-insensitively" do
    @unit.update!(display_name: "Depósito Ático")

    results = Units::Search.apply(Unit.all, term: "deposito atico")

    assert_includes results, @unit
  end

  test "scopes to residential property when provided" do
    other_property = create_property(@organization, "Search Property Two")
    other_unit = create_unit(other_property, "Torre A 101")

    results = Units::Search.apply(
      Unit.all,
      term: "torre a 101",
      residential_property_id: @property.id
    )

    assert_includes results, @unit
    assert_not_includes results, other_unit
  end
end
