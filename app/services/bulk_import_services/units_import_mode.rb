# frozen_string_literal: true

module BulkImportServices
  module UnitsImportMode
    DEFAULT = CreateUnitsImport::IMPORT_MODES[:create_skip_duplicates]

    def self.resolve(mode, default: DEFAULT)
      return mode if CreateUnitsImport::IMPORT_MODES.value?(mode)

      default
    end

    def update_only?
      import_mode == CreateUnitsImport::IMPORT_MODES[:update_only]
    end

    def allow_placement_changes?
      update_only?
    end

    def create_only?
      import_mode == CreateUnitsImport::IMPORT_MODES[:create_only]
    end

    def skip_duplicates?
      import_mode == CreateUnitsImport::IMPORT_MODES[:create_skip_duplicates]
    end
  end
end
