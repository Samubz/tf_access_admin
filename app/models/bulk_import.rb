# frozen_string_literal: true

# == Schema Information
#
# Table name: bulk_imports
#
#  id                      :uuid             not null, primary key
#  cancelled_at            :datetime
#  confirmed_at            :datetime
#  content_type            :string
#  error_rows              :integer          default(0), not null
#  expires_at              :datetime
#  failed_rows             :integer          default(0), not null
#  failure_message         :text
#  file_checksum           :string
#  file_size               :bigint
#  finished_at             :datetime
#  import_type             :string           not null
#  imported_rows           :integer          default(0), not null
#  metadata                :jsonb            not null
#  original_filename       :string
#  processing_started_at   :datetime
#  skipped_rows            :integer          default(0), not null
#  status                  :string           default("draft"), not null
#  summary                 :jsonb            not null
#  total_rows              :integer          default(0), not null
#  valid_rows              :integer          default(0), not null
#  validated_at            :datetime
#  warning_rows            :integer          default(0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  created_by_id           :uuid             not null
#  organization_id         :uuid             not null
#  property_section_id     :uuid
#  residential_property_id :uuid
#
# Indexes
#
#  index_bulk_imports_on_created_at                       (created_at)
#  index_bulk_imports_on_created_by_id                    (created_by_id)
#  index_bulk_imports_on_expires_at                       (expires_at)
#  index_bulk_imports_on_file_checksum                    (file_checksum)
#  index_bulk_imports_on_import_type                      (import_type)
#  index_bulk_imports_on_metadata                         (metadata) USING gin
#  index_bulk_imports_on_organization_id                  (organization_id)
#  index_bulk_imports_on_organization_id_and_created_at   (organization_id,created_at)
#  index_bulk_imports_on_organization_id_and_import_type  (organization_id,import_type)
#  index_bulk_imports_on_organization_id_and_status       (organization_id,status)
#  index_bulk_imports_on_property_section_id              (property_section_id)
#  index_bulk_imports_on_residential_property_id          (residential_property_id)
#  index_bulk_imports_on_status                           (status)
#  index_bulk_imports_on_summary                          (summary) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (property_section_id => property_sections.id)
#  fk_rails_...  (residential_property_id => residential_properties.id)
#
class BulkImport < ApplicationRecord
  include TenantScopedAssociations
  include AASM

  acts_as_tenant :organization

  IMPORT_TYPES = {
    units: "units",
    owners: "owners",
    residents: "residents",
    vehicles: "vehicles",
    staff: "staff",
    common_areas: "common_areas",
    users: "users"
  }.freeze

  belongs_to :organization
  belongs_to :created_by, class_name: "User"
  belongs_to :residential_property, optional: true
  belongs_to :property_section, optional: true

  has_many :rows,
           class_name: "BulkImportRow",
           foreign_key: :bulk_import_id,
           inverse_of: :bulk_import,
           dependent: :destroy

  has_one_attached :file

  validates :import_type, presence: true, inclusion: { in: IMPORT_TYPES.values }
  validates :status, presence: true
  validates :total_rows, numericality: { greater_than_or_equal_to: 0 }
  validates :valid_rows, numericality: { greater_than_or_equal_to: 0 }
  validates :warning_rows, numericality: { greater_than_or_equal_to: 0 }
  validates :error_rows, numericality: { greater_than_or_equal_to: 0 }
  validates :imported_rows, numericality: { greater_than_or_equal_to: 0 }
  validates :failed_rows, numericality: { greater_than_or_equal_to: 0 }
  validates :skipped_rows, numericality: { greater_than_or_equal_to: 0 }

  validates_same_tenant :residential_property, :property_section

  aasm column: :status, whiny_transitions: false do
    state :draft, initial: true
    state :uploaded
    state :validating
    state :validated
    state :validation_failed
    state :confirmed
    state :processing
    state :completed
    state :completed_with_errors
    state :failed
    state :cancelled
    state :expired

    event :mark_as_uploaded do
      transitions from: :draft, to: :uploaded
    end

    event :start_validation do
      transitions from: %i[uploaded validated validation_failed], to: :validating
    end

    event :complete_validation do
      transitions from: :validating, to: :validated
    end

    event :fail_validation do
      transitions from: :validating, to: :validation_failed
    end

    event :confirm do
      transitions from: :validated, to: :confirmed
    end

    event :start_processing do
      transitions from: :confirmed, to: :processing
    end

    event :complete do
      transitions from: :processing, to: :completed
    end

    event :complete_with_errors do
      transitions from: :processing, to: :completed_with_errors
    end

    event :fail_import do
      transitions from: :processing, to: :failed
    end

    event :cancel do
      transitions from: %i[draft uploaded validated validation_failed], to: :cancelled
    end

    event :expire do
      transitions from: %i[draft uploaded validated validation_failed], to: :expired
    end
  end

  scope :recent, -> { order(created_at: :desc) }

  scope :active, lambda {
    where.not(status: %w[completed completed_with_errors failed cancelled expired])
  }

  scope :completed, -> { where(status: %w[completed completed_with_errors]) }
  scope :failed, -> { where(status: "failed") }
  scope :by_import_type, ->(type) { where(import_type: type) }

  def has_errors?
    error_rows.positive? || failed_rows.positive?
  end

  def finished?
    completed? || completed_with_errors? || failed? || cancelled? || expired?
  end

  def progress_percentage
    return 0 if total_rows.zero?

    ((imported_rows + failed_rows + skipped_rows).to_f / total_rows * 100).round
  end
end
