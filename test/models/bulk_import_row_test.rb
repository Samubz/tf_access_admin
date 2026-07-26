# frozen_string_literal: true

# == Schema Information
#
# Table name: bulk_import_rows
#
#  id                        :uuid             not null, primary key
#  failed_at                 :datetime
#  failure_message           :text
#  group_key                 :string
#  import_status             :string           default("pending"), not null
#  imported_at               :datetime
#  normalized_payload        :jsonb            not null
#  onboarding_classification :string
#  operation                 :string
#  raw_payload               :jsonb            not null
#  row_number                :integer          not null
#  sheet_name                :string
#  skipped_at                :datetime
#  target_record_type        :string
#  validated_at              :datetime
#  validation_errors         :jsonb            not null
#  validation_status         :string           default("pending"), not null
#  validation_warnings       :jsonb            not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  bulk_import_id            :uuid             not null
#  target_record_id          :uuid
#
# Indexes
#
#  idx_on_target_record_type_target_record_id_ce961e50be           (target_record_type,target_record_id)
#  index_bulk_import_rows_on_bulk_import_id                        (bulk_import_id)
#  index_bulk_import_rows_on_bulk_import_id_and_group_key          (bulk_import_id,group_key)
#  index_bulk_import_rows_on_bulk_import_id_and_import_status      (bulk_import_id,import_status)
#  index_bulk_import_rows_on_bulk_import_id_and_row_number         (bulk_import_id,row_number) UNIQUE
#  index_bulk_import_rows_on_bulk_import_id_and_validation_status  (bulk_import_id,validation_status)
#  index_bulk_import_rows_on_normalized_payload                    (normalized_payload) USING gin
#  index_bulk_import_rows_on_raw_payload                           (raw_payload) USING gin
#  index_bulk_import_rows_on_row_number                            (row_number)
#
# Foreign Keys
#
#  fk_rails_...  (bulk_import_id => bulk_imports.id)
#
require "test_helper"

class BulkImportRowTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @user = users(:one)

    @bulk_import = BulkImport.create!(
      organization: @organization,
      created_by: @user,
      import_type: BulkImport::IMPORT_TYPES[:units]
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "creates a valid row with default statuses" do
    row = @bulk_import.rows.build(
      row_number: 1,
      raw_payload: { "identifier" => "101" },
      normalized_payload: { identifier: "101" }
    )

    assert row.save
    assert_equal BulkImportRow::VALIDATION_STATUSES[:pending], row.validation_status
    assert_equal BulkImportRow::IMPORT_STATUSES[:pending], row.import_status
  end

  test "enforces unique row_number per bulk import" do
    @bulk_import.rows.create!(row_number: 1)
    duplicate = @bulk_import.rows.build(row_number: 1)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:row_number], "has already been taken"
  end

  test "valid_for_import? accepts valid and warning rows" do
    valid_row = @bulk_import.rows.create!(
      row_number: 1,
      validation_status: BulkImportRow::VALIDATION_STATUSES[:valid]
    )
    warning_row = @bulk_import.rows.create!(
      row_number: 2,
      validation_status: BulkImportRow::VALIDATION_STATUSES[:warning]
    )
    error_row = @bulk_import.rows.create!(
      row_number: 3,
      validation_status: BulkImportRow::VALIDATION_STATUSES[:error]
    )

    assert valid_row.valid_for_import?
    assert warning_row.valid_for_import?
    assert_not error_row.valid_for_import?
  end
end
