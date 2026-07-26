# frozen_string_literal: true

module BulkImportServices
  # Organization-scoped counterpart to CreateUnitsImport for bulk person import
  # (add-bulk-user-import). Unlike units, people are not tied to a residential
  # property or section.
  class CreatePeopleImport
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(organization:, created_by:, file:, options: {})
      @organization = organization
      @created_by = created_by
      @file = file
      @options = options.stringify_keys
    end

    def call
      bulk_import = BulkImport.new(
        organization: @organization,
        created_by: @created_by,
        import_type: BulkImport::IMPORT_TYPES[:users]
      )

      # Inspect the Rack tempfile before attach: Active Storage uploads to disk in after_commit,
      # so blob.open would raise FileNotFoundError on a new, unsaved record.
      inspection = inspect_uploaded_file
      @file.rewind if @file.respond_to?(:rewind)

      bulk_import.file.attach(@file)
      assign_file_metadata!(bulk_import, inspection:)
      bulk_import.save!
      bulk_import.mark_as_uploaded! if bulk_import.may_mark_as_uploaded?

      bulk_import
    end

    private

    def assign_file_metadata!(bulk_import, inspection:)
      blob = bulk_import.file.blob

      bulk_import.original_filename = blob.filename.to_s
      bulk_import.content_type = blob.content_type
      bulk_import.file_size = blob.byte_size
      bulk_import.file_checksum = blob.checksum
      bulk_import.metadata = build_metadata(inspection)
    end

    def inspect_uploaded_file
      BulkImportServices::FileInspector.call(
        file_path: uploaded_file_path,
        filename: @file.original_filename,
        content_type: @file.content_type
      )
    end

    def uploaded_file_path
      if @file.respond_to?(:tempfile)
        @file.tempfile.path
      else
        @file.path
      end
    end

    def build_metadata(inspection)
      BulkImportServices::MetadataBuilder.call(
        inspection: inspection,
        options: persisted_options,
        column_mapper: BulkImportServices::PeopleColumnMapper
      )
    end

    def persisted_options
      defaults = { "import_mode" => PeopleImportMode::DEFAULT }
      defaults.merge(@options.slice("import_mode"))
    end
  end
end
