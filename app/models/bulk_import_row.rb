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
class BulkImportRow < ApplicationRecord
  VALIDATION_STATUSES = {
    pending: "pending",
    valid: "valid",
    warning: "warning",
    error: "error",
    duplicate: "duplicate"
  }.freeze

  IMPORT_STATUSES = {
    pending: "pending",
    imported: "imported",
    skipped: "skipped",
    failed: "failed"
  }.freeze

  # Onboarding classification recorded per row (bulk-import-people spec). The
  # importer only creates people for +ready_to_create_person+; every other value
  # is surfaced so a manager can act explicitly. No invitation is auto-sent.
  ONBOARDING_CLASSIFICATIONS = {
    ready_to_create_person: "ready_to_create_person",
    requires_invitation: "requires_invitation",
    requires_incorporation: "requires_incorporation",
    review: "review",
    conflict: "conflict",
    duplicate: "duplicate",
    invalid: "invalid"
  }.freeze

  belongs_to :bulk_import
  belongs_to :target_record, polymorphic: true, optional: true

  validates :row_number, presence: true
  validates :row_number, uniqueness: { scope: :bulk_import_id }
  validates :validation_status,
            presence: true,
            inclusion: { in: VALIDATION_STATUSES.values }
  validates :import_status,
            presence: true,
            inclusion: { in: IMPORT_STATUSES.values }

  scope :ordered, -> { order(:row_number) }

  scope :valid_rows, lambda {
    where(validation_status: VALIDATION_STATUSES[:valid])
  }

  scope :warning_rows, lambda {
    where(validation_status: VALIDATION_STATUSES[:warning])
  }

  scope :error_rows, lambda {
    where(validation_status: VALIDATION_STATUSES[:error])
  }

  scope :pending_import, lambda {
    where(import_status: IMPORT_STATUSES[:pending])
  }

  scope :imported, lambda {
    where(import_status: IMPORT_STATUSES[:imported])
  }

  scope :failed_import, lambda {
    where(import_status: IMPORT_STATUSES[:failed])
  }

  scope :by_group_key, ->(group_key) { where(group_key: group_key) }

  def valid_for_import?
    validation_status.in?([
      VALIDATION_STATUSES[:valid],
      VALIDATION_STATUSES[:warning]
    ])
  end

  def has_errors?
    validation_errors.present? || import_status == IMPORT_STATUSES[:failed]
  end

  def has_warnings?
    validation_warnings.present?
  end
end
