# frozen_string_literal: true

module BulkImportServices
  class UpdatePeopleImport
    CONFIGURABLE_STATUSES = %w[draft uploaded validated validation_failed].freeze

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(bulk_import:, file: nil, selected_sheet: nil, options: {})
      @bulk_import = bulk_import
      @file = file
      @selected_sheet = selected_sheet
      @options = options.stringify_keys
    end

    def call
      validate_configurable!

      if @file.present?
        replace_file_and_metadata!
      elsif @selected_sheet.present?
        refresh_sheet_metadata!
      else
        update_options_only!
      end

      @bulk_import.save!
      @bulk_import
    end

    private

    def validate_configurable!
      return if CONFIGURABLE_STATUSES.include?(@bulk_import.status)

      @bulk_import.errors.add(:status, :invalid)
      raise ActiveRecord::RecordInvalid, @bulk_import
    end

    def replace_file_and_metadata!
      inspection = inspect_uploaded_file(@file)
      @file.rewind if @file.respond_to?(:rewind)

      @bulk_import.file.attach(@file)
      assign_file_attributes_from_blob!
      @bulk_import.metadata = build_metadata(inspection)
    end

    def refresh_sheet_metadata!
      inspection = inspect_attached_file(selected_sheet: @selected_sheet)
      @bulk_import.metadata = build_metadata(inspection)
    end

    def update_options_only!
      metadata = @bulk_import.metadata.deep_dup
      metadata["options"] = metadata.fetch("options", {}).merge(persisted_options)
      metadata["file_inspection"] = metadata.fetch("file_inspection", {})
      @bulk_import.metadata = metadata
    end

    def build_metadata(inspection)
      BulkImportServices::MetadataBuilder.call(
        inspection: inspection,
        options: persisted_options,
        column_mapper: BulkImportServices::PeopleColumnMapper
      )
    end

    def persisted_options
      current = @bulk_import.metadata.fetch("options", {})
      defaults = { "import_mode" => current["import_mode"] || PeopleImportMode::DEFAULT }
      defaults.merge(@options.slice("import_mode"))
    end

    def assign_file_attributes_from_blob!
      blob = @bulk_import.file.blob

      @bulk_import.original_filename = blob.filename.to_s
      @bulk_import.content_type = blob.content_type
      @bulk_import.file_size = blob.byte_size
      @bulk_import.file_checksum = blob.checksum
    end

    def inspect_uploaded_file(file)
      BulkImportServices::FileInspector.call(
        file_path: uploaded_file_path(file),
        filename: file.original_filename,
        content_type: file.content_type
      )
    end

    def inspect_attached_file(selected_sheet:)
      raise ActiveStorage::FileNotFoundError unless @bulk_import.file.attached?

      @bulk_import.file.blob.open do |tempfile|
        BulkImportServices::FileInspector.call(
          file_path: tempfile.path,
          filename: @bulk_import.original_filename.to_s,
          content_type: @bulk_import.content_type,
          selected_sheet: selected_sheet
        )
      end
    end

    def uploaded_file_path(file)
      if file.respond_to?(:tempfile)
        file.tempfile.path
      else
        file.path
      end
    end
  end
end
