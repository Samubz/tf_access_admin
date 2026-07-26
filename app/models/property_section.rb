# frozen_string_literal: true

# == Schema Information
#
# Table name: property_sections
#
#  id                      :uuid             not null, primary key
#  code                    :string
#  deleted_at              :datetime
#  metadata                :jsonb            not null
#  name                    :string           not null
#  normalized_name         :string           not null
#  position                :integer
#  section_type            :string           not null
#  status                  :string           default("active"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  organization_id         :uuid             not null
#  parent_id               :uuid
#  residential_property_id :uuid             not null
#
# Indexes
#
#  idx_property_sections_on_org_property_parent        (organization_id,residential_property_id,parent_id)
#  idx_property_sections_property_parent_position      (residential_property_id,parent_id,position)
#  idx_property_sections_unique_child_name             (organization_id,residential_property_id,parent_id,normalized_name) UNIQUE WHERE ((parent_id IS NOT NULL) AND (deleted_at IS NULL))
#  idx_property_sections_unique_code_in_context        (organization_id,residential_property_id,parent_id,section_type,code) UNIQUE WHERE ((code IS NOT NULL) AND (deleted_at IS NULL))
#  idx_property_sections_unique_root_name              (organization_id,residential_property_id,normalized_name) UNIQUE WHERE ((parent_id IS NULL) AND (deleted_at IS NULL))
#  index_property_sections_on_deleted_at               (deleted_at)
#  index_property_sections_on_metadata                 (metadata) USING gin
#  index_property_sections_on_organization_id          (organization_id)
#  index_property_sections_on_parent_id                (parent_id)
#  index_property_sections_on_residential_property_id  (residential_property_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (parent_id => property_sections.id)
#  fk_rails_...  (residential_property_id => residential_properties.id)
#
class PropertySection < ApplicationRecord
  include SectionTypes
  include SectionStatuses
  include NormalizableAttributes
  include AlphanumericHyphenCodeValidatable
  include TenantScopedAssociations
  include PropertySectionHierarchy

  # Maps unique DB indexes to the field that should carry a domain error when a
  # concurrent insert/update trips them (improve-property-sections §2.10).
  UNIQUE_INDEX_FIELDS = {
    "idx_property_sections_unique_root_name" => :name,
    "idx_property_sections_unique_child_name" => :name,
    "idx_property_sections_unique_code_in_context" => :code
  }.freeze

  acts_as_tenant :organization
  acts_as_paranoid

  # Hierarchy, ordering, type and lifecycle changes are audited
  # (improve-property-sections §1.9).
  audited only: %i[name parent_id position section_type status]

  belongs_to :organization
  belongs_to :residential_property
  belongs_to :parent, class_name: "PropertySection", optional: true, inverse_of: :children
  # The lifecycle contract replaces destructive deletion with archiving
  # (improve-property-sections §"Delete vs archive strategy"). A section with
  # children, units or visits must not be removed physically or logically through
  # the ordinary flow, so these associations guard against accidental destructive
  # cascades with +restrict_with_error+ instead of cascading +destroy+. Archive is
  # the supported retirement operation and preserves the subtree and references.
  has_many :children, class_name: "PropertySection", foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_error
  has_many :units, dependent: :restrict_with_error
  has_many :visits, dependent: :restrict_with_error

  validates :section_type, presence: true, inclusion: { in: SectionTypes::ALL }
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: SectionStatuses::ALL }
  validates :organization, presence: true
  validates :residential_property, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true
  validates_alphanumeric_hyphen_code :code

  # Hierarchy/parent rules (auto-parent, same org/property, two-level limit,
  # cycles, operativity) live in PropertySectionHierarchy — the single source of
  # truth (improve-property-sections §3.1).
  validate :organization_matches_property
  validate :name_unique_among_siblings
  # §2.3: +residential_property_id+ is immutable for the section's whole life.
  # (organization immutability is enforced by acts_as_tenant, which raises
  # TenantIsImmutable on any tenant change of a persisted record.)
  validate :residential_property_immutable, on: :update

  normalizes :section_type, with: ->(value) { value.to_s.strip.downcase.presence }
  normalizes :status, with: ->(value) { value.to_s.strip.downcase.presence }

  before_validation :normalize_name
  before_validation :normalize_optional_attributes
  before_validation :assign_normalized_name
  before_validation :assign_default_position, on: :create
  trims_attributes :code

  # Whether this section's type is eligible to directly contain units (§2.8).
  def eligible_for_units?
    SectionTypes.eligible_for_units?(section_type)
  end

  # Canonical structural eligibility contract consumed by the Unit domain
  # (improve-units-foundation §1.6): a section can directly hold units only when
  # its type is unit-eligible and it currently has no subsections. Effective
  # activity is evaluated separately by callers (via +effectively_active?+), so
  # this method stays a pure structural predicate. Unit code must rely on this
  # method instead of duplicating the section-type list.
  def can_contain_units?
    eligible_for_units? && accepts_units?
  end

  # Translates a concurrent unique-violation into a field-level domain error
  # instead of letting +ActiveRecord::RecordNotUnique+ surface as a 500. The
  # lifecycle services (§4) rescue the exception and delegate here so the
  # index→field mapping stays with the model (improve-property-sections §2.10).
  def register_uniqueness_conflict(exception)
    message = exception.message.to_s
    field = UNIQUE_INDEX_FIELDS.find { |index, _| message.include?(index) }&.last || :base
    errors.add(field, :taken)
    self
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[name code section_type position residential_property_id]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[residential_property parent]
  end

  private

  def normalize_optional_attributes
    self.code = code.presence
    self.parent_id = parent_id.presence
  end

  # Canonical display name: trim plus internal whitespace collapse (§2.1).
  def normalize_name
    self.name = name.strip.gsub(/\s+/, " ").presence if name.present?
  end

  # Comparison value for sibling-name uniqueness: trim, whitespace collapse,
  # Unicode NFKC normalization and case folding (§2.1). Populates the NOT NULL
  # +normalized_name+ column used by the unique indexes (§1.2).
  def self.normalize_name(value)
    value.to_s.strip.gsub(/\s+/, " ").unicode_normalize(:nfkc).downcase.presence
  end

  def assign_normalized_name
    self.normalized_name = self.class.normalize_name(name)
  end

  # §2.2: the section's organization must match its property's organization.
  def organization_matches_property
    return if residential_property.blank? || organization_id.blank?
    return if residential_property.organization_id == organization_id

    errors.add(:organization_id, :mismatch_property)
  end

  # §2.4/§2.5: normalized name must be unique among non-deleted siblings sharing
  # the same property and parent context (root context when +parent_id+ is nil),
  # which is why the same name is allowed under a different parent.
  def name_unique_among_siblings
    return if normalized_name.blank? || residential_property_id.blank?

    scope = self.class.where(
      residential_property_id: residential_property_id,
      parent_id: parent_id,
      normalized_name: normalized_name
    )
    scope = scope.where.not(id: id) if persisted?

    errors.add(:name, :taken) if scope.exists?
  end

  # §2.3: a section never moves to another property.
  def residential_property_immutable
    errors.add(:residential_property_id, :immutable) if residential_property_id_changed?
  end

  def assign_default_position
    return if position.present?

    siblings = self.class.where(
      residential_property_id: residential_property_id,
      parent_id: parent_id
    )
    siblings = siblings.where.not(id: id) if persisted?
    self.position = (siblings.maximum(:position) || 0) + 1
  end
end
