# frozen_string_literal: true

require "test_helper"

class PropertyStatusesTest < ActiveSupport::TestCase
  test "includes draft and configured in ALL and OPERABLE" do
    assert_includes PropertyStatuses::ALL, PropertyStatuses::DRAFT
    assert_includes PropertyStatuses::ALL, PropertyStatuses::CONFIGURED
    assert_includes PropertyStatuses::OPERABLE, PropertyStatuses::DRAFT
    assert_includes PropertyStatuses::OPERABLE, PropertyStatuses::CONFIGURED
    assert_includes PropertyStatuses::SETUP, PropertyStatuses::DRAFT
    assert_includes PropertyStatuses::SETUP, PropertyStatuses::CONFIGURED
  end
end
