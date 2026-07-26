# frozen_string_literal: true

require "test_helper"

# Single source of truth for "prefix + suffix" section naming, shared by the
# quick engine and the manual builder batch (wizard-manual-structure-builder).
class Properties::Setup::SectionNameSequenceTest < ActiveSupport::TestCase
  Sequence = Properties::Setup::SectionNameSequence

  test "generates letter-suffixed names" do
    assert_equal %w[Torre\ A Torre\ B Torre\ C],
                 Sequence.names(prefix: "Torre", suffix_type: :letter, count: 3)
  end

  test "generates number-suffixed names" do
    assert_equal [ "Piso 1", "Piso 2" ],
                 Sequence.names(prefix: "Piso", suffix_type: :number, count: 2)
  end

  test "name returns a single zero-based entry" do
    assert_equal "Torre A", Sequence.name(prefix: "Torre", suffix_type: :letter, index: 0)
    assert_equal "Piso 3", Sequence.name(prefix: "Piso", suffix_type: :number, index: 2)
  end

  test "blank prefix yields the bare suffix" do
    assert_equal "A", Sequence.name(prefix: "", suffix_type: :letter, index: 0)
  end

  test "non-positive count yields an empty list" do
    assert_empty Sequence.names(prefix: "Torre", suffix_type: :letter, count: 0)
  end

  test "available_names skips taken normalized siblings without parsing suffixes" do
    taken = [ PropertySection.normalize_name("Torre A"), PropertySection.normalize_name("Torre 123") ]

    assert_equal [ "Torre B", "Torre C" ],
                 Sequence.available_names(
                   prefix: "Torre", suffix_type: :letter, count: 2,
                   taken_normalized_names: taken
                 )
  end

  test "available_names allocates numeric names when only a non-sequential name is taken" do
    taken = [ PropertySection.normalize_name("Torre 123") ]

    assert_equal [ "Torre 1", "Torre 2" ],
                 Sequence.available_names(
                   prefix: "Torre", suffix_type: :number, count: 2,
                   taken_normalized_names: taken
                 )
  end

  test "available_names returns fewer than count when suffix range is exhausted" do
    taken = Array.new(26) { |index| PropertySection.normalize_name("Torre #{('A'.ord + index).chr}") }

    assert_equal [], Sequence.available_names(
      prefix: "Torre", suffix_type: :letter, count: 1,
      taken_normalized_names: taken
    )
  end
end
