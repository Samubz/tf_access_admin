# frozen_string_literal: true

require "test_helper"

module BulkImportServices
  class UnitsImportOptionsTest < ActiveSupport::TestCase
    test "OwnerImportMode.resolve returns known modes" do
      assert_equal "link_existing", OwnerImportMode.resolve("link_existing")
    end

    test "OwnerImportMode.resolve falls back for unknown modes" do
      assert_equal OwnerImportMode::DEFAULT, OwnerImportMode.resolve("invalid")
      assert_equal OwnerImportMode::DEFAULT, OwnerImportMode.resolve(nil)
    end

    test "UnitsImportMode.resolve returns known modes" do
      assert_equal "update_only", UnitsImportMode.resolve("update_only")
    end

    test "UnitsImportMode.resolve falls back for unknown modes" do
      assert_equal UnitsImportMode::DEFAULT, UnitsImportMode.resolve("invalid")
    end

    test "allow_placement_changes is true only for update_only" do
      importer = Object.new
      importer.extend(UnitsImportMode)
      importer.define_singleton_method(:import_mode) { "update_only" }
      assert importer.allow_placement_changes?

      importer.define_singleton_method(:import_mode) { "create_only" }
      assert_not importer.allow_placement_changes?
    end
  end
end
