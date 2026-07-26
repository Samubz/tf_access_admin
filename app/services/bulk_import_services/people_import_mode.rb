# frozen_string_literal: true

module BulkImportServices
  module PeopleImportMode
    IMPORT_MODES = {
      create_skip_duplicates: "create_skip_duplicates",
      create_only: "create_only"
    }.freeze

    DEFAULT = IMPORT_MODES[:create_skip_duplicates]

    def self.resolve(mode, default: DEFAULT)
      return mode if IMPORT_MODES.value?(mode)

      default
    end

    def create_only?
      import_mode == IMPORT_MODES[:create_only]
    end

    def skip_duplicates?
      import_mode == IMPORT_MODES[:create_skip_duplicates]
    end
  end
end
