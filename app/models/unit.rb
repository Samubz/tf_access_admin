# frozen_string_literal: true

# == Schema Information
#
# Table name: units
#
#  id                      :uuid             not null, primary key
#  area_m2                 :decimal(10, 2)
#  code                    :string
#  deleted_at              :datetime
#  display_name            :string
#  identifier              :string           not null
#  metadata                :jsonb            not null
#  normalized_identifier   :string           not null
#  status                  :string           default("available"), not null
#  unit_type               :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  organization_id         :uuid             not null
#  property_section_id     :uuid
#  residential_property_id :uuid             not null
#
# Indexes
#
#  idx_on_organization_id_residential_property_id_stat_47cefd6e3a  (organization_id,residential_property_id,status)
#  idx_units_on_org_property_normalized_identifier_lookup          (organization_id,residential_property_id,normalized_identifier) WHERE (deleted_at IS NULL)
#  idx_units_unique_code_in_property_root                          (organization_id,residential_property_id,code) UNIQUE WHERE ((deleted_at IS NULL) AND (property_section_id IS NULL) AND (code IS NOT NULL))
#  idx_units_unique_code_in_section                                (organization_id,residential_property_id,property_section_id,code) UNIQUE WHERE ((deleted_at IS NULL) AND (property_section_id IS NOT NULL) AND (code IS NOT NULL))
#  index_units_on_deleted_at                                       (deleted_at)
#  index_units_on_metadata                                         (metadata) USING gin
#  index_units_on_org_property_normalized_when_no_section          (organization_id,residential_property_id,normalized_identifier) UNIQUE WHERE ((property_section_id IS NULL) AND (deleted_at IS NULL))
#  index_units_on_org_property_section_normalized_when_section     (organization_id,residential_property_id,property_section_id,normalized_identifier) UNIQUE WHERE ((property_section_id IS NOT NULL) AND (deleted_at IS NULL))
#  index_units_on_organization_id                                  (organization_id)
#  index_units_on_organization_id_and_property_section_id          (organization_id,property_section_id)
#  index_units_on_property_section_id                              (property_section_id)
#  index_units_on_residential_property_id                          (residential_property_id)
#
# Foreign Keys
#
#  fk_rails_...                                         (organization_id => organizations.id)
#  fk_rails_...                                         (property_section_id => property_sections.id)
#  fk_rails_...                                         (residential_property_id => residential_properties.id)
#  fk_units_organization_residential_property_coherent  ([organization_id, residential_property_id] => residential_properties[organization_id, id])
#
class Unit < ApplicationRecord
  include AlphanumericHyphenCodeValidatable
  include NormalizableAttributes
  include TenantScopedAssociations
  include UnitTypes
  include UnitStatuses

  # Metadata keys that mirror structural/lifecycle/authorization fields. Metadata
  # is non-authoritative, so these are stripped to guarantee they can never act as
  # a source of truth (improve-units-foundation §1.14).
  RESERVED_METADATA_KEYS = %w[
    organization organization_id residential_property residential_property_id
    property property_section property_section_id section section_id
    identifier normalized_identifier unit_type type status lifecycle
    deleted_at area_m2 role roles capability capabilities permission permissions
    authorization access
  ].freeze

  acts_as_tenant :organization
  acts_as_paranoid

  # §3.4: soft delete is only allowed through +Units::SoftDelete+ (or an explicit
  # +authorize_soft_delete!+ in tests). Business retirement uses +Units::Archive+.
  before_destroy :ensure_soft_delete_authorized

  # Identity, placement, type, status and area changes are audited (§1.17).
  audited only: %i[identifier display_name status unit_type area_m2 property_section_id]

  belongs_to :organization
  belongs_to :residential_property
  belongs_to :property_section, optional: true

  # §3.4: soft delete and archive preserve all relationships (no cascade
  # destroy). Removing dependent: ensures destroy does not touch related records.
  has_many :unit_ownerships
  has_many :lease_contracts
  has_many :unit_occupancies
  has_many :authorized_residents
  has_many :visits

  # §1.1 minimal contract: presence of the identity/placement/type/status fields.
  validates :identifier, presence: true
  validates_alphanumeric_hyphen_code :identifier, allow_whitespace: true
  # System-derived machine key (hierarchical-code-generation); strict slug format.
  # The validator already skips blank values, so the nullable code is optional.
  validates_alphanumeric_hyphen_code :code
  validates :normalized_identifier, presence: true
  validates :unit_type, presence: true
  validates :status, presence: true, inclusion: { in: UnitStatuses::ALL }
  validates :organization, presence: true
  validates :residential_property, presence: true
  # §1.12: optional area, strictly positive when present.
  validates :area_m2, numericality: { greater_than: 0 }, allow_nil: true

  normalizes :unit_type, with: ->(value) { value.to_s.strip.downcase.presence }
  normalizes :status, with: ->(value) { value.to_s.strip.downcase.presence }

  # §1.16: a write that sets/changes +unit_type+ must use the canonical catalog;
  # legacy values persist untouched but cannot be introduced on new writes (§1.15).
  validate :unit_type_in_canonical_catalog, if: :unit_type_canonical_required?

  validates_same_tenant :residential_property, :property_section
  # §1.3: organization and residential property are immutable for the unit's life
  # (organization immutability is enforced by acts_as_tenant, which raises on any
  # tenant change of a persisted record).
  validate :residential_property_immutable, on: :update
  # §1.4/§1.5/§1.6: optional section must exist, share organization+property, be
  # effectively active and be eligible to contain units per the section contract.
  validate :property_section_must_exist
  validate :property_section_same_property
  validate :property_section_operative
  validate :property_section_can_contain_units
  # §1.8: uniqueness by placement context, treating "no section" as one logical
  # context (the DB index alone cannot, since NULLs are distinct in Postgres).
  validate :identifier_unique_in_context
  # Derived code is unique within the same placement context (nil section is its
  # own context), matching the partial unique indexes.
  validate :code_unique_in_context

  before_validation :derive_organization_from_property, on: :create
  before_validation :assign_normalized_identifier
  before_validation :sanitize_metadata
  trims_attributes :identifier

  def self.ransackable_attributes(_auth_object = nil)
    %w[identifier display_name normalized_identifier]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  # Marks the record so +destroy+ may run through acts_as_paranoid. Production
  # code sets this only from +Units::SoftDelete+.
  def authorize_soft_delete!
    @soft_delete_authorized = true
    self
  end

  def archived?
    status == UnitStatuses::ARCHIVED
  end

  private

  attr_reader :soft_delete_authorized

  def ensure_soft_delete_authorized
    return if soft_delete_authorized

    errors.add(:base, :destroy_requires_service)
    throw(:abort)
  end

  # §1.2: organization is derived from the trusted property context, not the client.
  def derive_organization_from_property
    return if residential_property.blank?

    self.organization_id = residential_property.organization_id
  end

  def assign_normalized_identifier
    return if identifier.blank?

    result = Units::NormalizeIdentifier.call(identifier)
    return unless result

    self.identifier = result.identifier
    self.normalized_identifier = result.normalized_identifier
  end

  # §1.13/§1.14: metadata stays extensible but never overrides structural fields.
  def sanitize_metadata
    return unless metadata.is_a?(Hash)

    self.metadata = metadata.reject { |key, _| RESERVED_METADATA_KEYS.include?(key.to_s) }
  end

  def unit_type_canonical_required?
    unit_type.present? && (new_record? || unit_type_changed?)
  end

  def unit_type_in_canonical_catalog
    return if UnitTypes::CANONICAL.include?(unit_type)

    errors.add(:unit_type, t_validation("unit_type_invalid"))
  end

  def residential_property_immutable
    errors.add(:residential_property_id, t_validation("residential_property_immutable")) if residential_property_id_changed?
  end

  # §"Property and section coherence": a non-blank but unresolvable section id is
  # an error, never silently treated as "no section".
  def property_section_must_exist
    return if property_section_id.blank?
    return if property_section.present?

    errors.add(:property_section_id, t_validation("section_invalid"))
  end

  def property_section_same_property
    return if property_section.blank?
    return if property_section.residential_property_id == residential_property_id

    errors.add(:property_section_id, t_validation("section_same_property"))
  end

  # §1.5: only validated when the section is assigned or changed, so a unit under
  # an already-placed section is not blocked by later ancestor status changes.
  def property_section_operative
    return if property_section.blank?
    return unless new_record? || property_section_id_changed?
    return if property_section.effectively_active?

    errors.add(:property_section_id, t_validation("section_not_operative"))
  end

  # §1.6: eligibility is delegated to the property-section contract; Unit never
  # hardcodes the eligible section-type list.
  def property_section_can_contain_units
    return if property_section.blank?
    return if property_section.can_contain_units?

    errors.add(:property_section_id, t_validation("section_not_eligible"))
  end

  # §1.8/§1.9: unique among non-deleted units sharing organization, property and
  # section context (nil section is its own context). acts_as_paranoid's default
  # scope already excludes soft-deleted rows, matching +deleted_at IS NULL+.
  def identifier_unique_in_context
    return if normalized_identifier.blank? || residential_property_id.blank?

    scope = self.class.where(
      residential_property_id: residential_property_id,
      property_section_id: property_section_id,
      normalized_identifier: normalized_identifier
    )
    scope = scope.where.not(id: id) if persisted?

    errors.add(:identifier, t_validation("identifier_taken")) if scope.exists?
  end

  def code_unique_in_context
    return if code.blank? || residential_property_id.blank?

    scope = self.class.where(
      residential_property_id: residential_property_id,
      property_section_id: property_section_id,
      code: code
    )
    scope = scope.where.not(id: id) if persisted?

    errors.add(:code, t_validation("code_taken")) if scope.exists?
  end

  # Translates a +ActiveRecord::RecordNotUnique+ DB exception into a field error
  # so services can surface it as a domain conflict rather than a 500
  # (improve-units-foundation §2.9). The index→field mapping lives here so it
  # travels with the model schema comment above.
  UNIQUE_INDEX_FIELDS = {
    "index_units_on_org_property_section_normalized_when_section" => :identifier,
    "index_units_on_org_property_normalized_when_no_section" => :identifier,
    "idx_units_unique_normalized_id_per_context" => :identifier,
    "idx_units_unique_code_in_section" => :code,
    "idx_units_unique_code_in_property_root" => :code
  }.freeze

  def register_uniqueness_conflict(exception)
    field = UNIQUE_INDEX_FIELDS.find { |index, _| exception.message.include?(index) }&.last || :identifier
    errors.add(field, t_validation(field == :code ? "code_taken" : "identifier_taken"))
    self
  end

  def t_validation(key)
    I18n.t("frontend.admin.units.validations.#{key}")
  end
end
