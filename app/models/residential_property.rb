# frozen_string_literal: true

# == Schema Information
#
# Table name: residential_properties
#
#  id              :uuid             not null, primary key
#  address_line    :string
#  city            :string
#  code            :string
#  country         :string           default("Chile"), not null
#  deleted_at      :datetime
#  metadata        :jsonb            not null
#  name            :string           not null
#  normalized_name :string           not null
#  property_type   :string           not null
#  region          :string
#  status          :string           default("active"), not null
#  timezone        :string           default("America/Santiago"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#
# Indexes
#
#  idx_on_organization_id_property_type_d2e2ee8ca6             (organization_id,property_type)
#  idx_residential_properties_organization_id_id               (organization_id,id) UNIQUE
#  idx_residential_properties_unique_code_per_org              (organization_id,code) UNIQUE WHERE ((code IS NOT NULL) AND (deleted_at IS NULL))
#  idx_residential_properties_unique_normalized_name_per_org   (organization_id,normalized_name) UNIQUE WHERE (deleted_at IS NULL)
#  index_residential_properties_on_deleted_at                  (deleted_at)
#  index_residential_properties_on_metadata                    (metadata) USING gin
#  index_residential_properties_on_organization_id             (organization_id)
#  index_residential_properties_on_organization_id_and_status  (organization_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
class ResidentialProperty < ApplicationRecord
  include PropertyTypes
  include PropertyStatuses
  include NormalizableAttributes

  # Maps unique DB indexes to the field that should carry a domain error when a
  # concurrent insert/update trips them (improve-property-foundation §2.8).
  UNIQUE_INDEX_FIELDS = {
    "idx_residential_properties_unique_normalized_name_per_org" => :name,
    "idx_residential_properties_unique_code_per_org" => :code
  }.freeze

  acts_as_tenant :organization
  acts_as_paranoid

  # Lifecycle/state changes are audited (improve-property-foundation §1.8).
  audited only: %i[name status property_type]

  belongs_to :organization
  # NOTE (improve-property-foundation §1.7): these associations still use
  # +dependent: :destroy+. The lifecycle contract replaces destructive deletion
  # with archiving, so the cascade must not be relied on as a lifecycle mechanism.
  # Removing/guarding the cascade is handled by the archive service work (§3),
  # not by this model/migration section.
  has_many :property_sections, dependent: :destroy
  has_many :units, dependent: :destroy
  has_many :visits, dependent: :destroy
  has_one :property_setting, dependent: :destroy

  validates :name, presence: true
  validates :property_type, presence: true, inclusion: { in: PropertyTypes::ALL }
  validates :status, presence: true, inclusion: { in: PropertyStatuses::ALL }
  validates :code, uniqueness: { scope: :organization_id }, allow_blank: true
  validates :country, presence: true
  validates :timezone, presence: true

  validate :name_unique_within_organization
  validate :timezone_is_valid
  # §2.7: +organization_id+ immutability is enforced by +acts_as_tenant+, which
  # raises +ActsAsTenant::Errors::TenantIsImmutable+ on any attempt to change the
  # tenant of a persisted record. The lifecycle services (§3) rescue that and add
  # the +organization_id.immutable+ field error for a graceful domain result.

  before_validation :normalize_name
  before_validation :normalize_optional_strings
  before_validation :assign_normalized_name
  trims_attributes :code, :address_line, :city, :region, :country, :timezone

  def self.ransackable_attributes(_auth_object = nil)
    %w[name code city region address_line status property_type]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  # Translates a concurrent unique-violation into a field-level domain error
  # instead of letting +ActiveRecord::RecordNotUnique+ surface as a 500. The
  # lifecycle services (§3) rescue the exception and delegate here so the
  # index→field mapping stays with the model (improve-property-foundation §2.8).
  def register_uniqueness_conflict(exception)
    message = exception.message.to_s
    field = UNIQUE_INDEX_FIELDS.find { |index, _| message.include?(index) }&.last || :base
    errors.add(field, :taken)
    self
  end

  private

  # Canonical display name: trim plus internal whitespace collapse
  # (improve-property-foundation §2.1).
  def normalize_name
    self.name = name.strip.gsub(/\s+/, " ").presence if name.present?
  end

  def normalize_optional_strings
    self.code = code.presence
    self.address_line = address_line.presence
    self.city = city.presence
    self.region = region.presence
  end

  # Mirrors the SQL backfill expression: trim, collapse whitespace, downcase.
  # Populates the NOT NULL +normalized_name+ column used by the tenant-scoped
  # case-insensitive uniqueness index (improve-property-foundation §1.4).
  def assign_normalized_name
    self.normalized_name = name.to_s.strip.gsub(/\s+/, " ").downcase.presence
  end

  # Case-insensitive name uniqueness scoped to the organization, comparing the
  # normalized form and excluding soft-deleted rows via the default scope. The
  # error is attached to +name+ so the UI surfaces it as a field error
  # (improve-property-foundation §2.2).
  def name_unique_within_organization
    return if normalized_name.blank? || organization_id.blank?

    scope = self.class.where(organization_id: organization_id, normalized_name: normalized_name)
    scope = scope.where.not(id: id) if persisted?

    errors.add(:name, :taken) if scope.exists?
  end

  # Validates that +timezone+ resolves to a real zone (§2.6).
  def timezone_is_valid
    return if timezone.blank?

    errors.add(:timezone, :invalid_timezone) if ActiveSupport::TimeZone[timezone].nil?
  end
end
