# frozen_string_literal: true

# == Schema Information
#
# Table name: people
#
#  id                         :uuid             not null, primary key
#  birthdate                  :date
#  deleted_at                 :datetime
#  display_name               :string           not null
#  document_number_ciphertext :text
#  document_number_digest     :string
#  document_type              :string
#  email_ciphertext           :text
#  first_name                 :string
#  last_name                  :string
#  metadata                   :jsonb            not null
#  person_type                :string           default("natural"), not null
#  phone_ciphertext           :text
#  status                     :string           default("active"), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  organization_id            :uuid             not null
#  user_id                    :uuid
#
# Indexes
#
#  idx_people_unique_document_per_org_when_present   (organization_id,document_type,document_number_digest) UNIQUE WHERE ((document_number_digest IS NOT NULL) AND (deleted_at IS NULL))
#  idx_people_unique_user_per_org_when_present       (organization_id,user_id) UNIQUE WHERE ((user_id IS NOT NULL) AND (deleted_at IS NULL))
#  index_people_on_deleted_at                        (deleted_at)
#  index_people_on_metadata                          (metadata) USING gin
#  index_people_on_organization_id                   (organization_id)
#  index_people_on_organization_id_and_display_name  (organization_id,display_name)
#  index_people_on_organization_id_and_status        (organization_id,status)
#  index_people_on_organization_id_and_user_id       (organization_id,user_id)
#  index_people_on_user_id                           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (user_id => users.id)
#
class Person < ApplicationRecord
  include PersonTypes
  include PersonStatuses

  acts_as_tenant :organization
  acts_as_paranoid
  rolify

  audited only: %i[display_name first_name last_name status user_id document_type]

  attr_accessor :document_number, :contact_email, :contact_phone

  belongs_to :organization
  belongs_to :user, optional: true
  has_one :organization_membership, dependent: :destroy
  has_many :unit_ownerships, dependent: :destroy
  has_many :unit_occupancies, dependent: :destroy
  # Extended visitor profiles; see +VisitorProfile+ for the person_id contract.
  has_many :visitor_profiles, dependent: :destroy
  has_many :staff_assignments, dependent: :destroy
  has_many :visits_as_visitor, class_name: "Visit", foreign_key: :visitor_person_id, dependent: :destroy
  has_many :onboarding_requests, dependent: :destroy

  validates :display_name, presence: true
  validates :person_type, presence: true, inclusion: { in: PersonTypes::ALL }
  validates :status, presence: true, inclusion: { in: PersonStatuses::ALL }
  validates :user_id, uniqueness: {
    scope: :organization_id,
    allow_nil: true,
    conditions: -> { where(deleted_at: nil) }
  }

  validate :document_unique_within_organization
  validate :email_unique_within_organization

  before_validation :assign_display_name
  before_validation :sync_document_attributes
  before_validation :sync_contact_attributes
  before_validation :assign_person_type
  before_validation :assign_default_status
  before_validation :assign_default_document_type

  def document_number
    @document_number || metadata["document_number"]
  end

  def document_number=(value)
    @document_number = value.to_s.strip.presence
  end

  def contact_email
    @contact_email || metadata["import_email"] || user&.email
  end

  def contact_email=(value)
    @contact_email = value.to_s.downcase.strip.presence
  end

  def contact_phone
    @contact_phone || metadata["phone"]
  end

  def contact_phone=(value)
    @contact_phone = value.to_s.strip.presence
  end

  def tenant_role
    tenant_roles = roles.select do |role|
      role.resource_type == "Organization" && role.resource_id == organization_id.to_s
    end
    return nil if tenant_roles.blank?

    tenant_roles.min_by { |role| AvailableRoles.priority_index(role.name, :tenant) }.name
  end

  def set_tenant_role(role_name)
    delete_tenant_roles
    add_role(role_name, organization) unless has_role?(role_name, organization)
  end

  def contextual_roles
    People::ContextualRoles.call(self)
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[display_name first_name last_name status person_type document_number_digest]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[user]
  end

  private

  def assign_display_name
    return if display_name.present?

    parts = [ first_name, last_name ].compact_blank
    self.display_name = parts.join(" ").presence || contact_email || document_number || "—"
  end

  def assign_person_type
    return if person_type.present?

    self.person_type = "natural"
  end

  def assign_default_status
    return if status.present?

    self.status = "active"
  end

  def assign_default_document_type
    return if document_type.present?

    self.document_type ||= "national_id"
  end

  def sync_document_attributes
    return if @document_number.blank?

    self.document_number_digest = self.class.document_digest(@document_number)
    self.metadata = metadata.merge("document_number" => @document_number)
  end

  def sync_contact_attributes
    self.metadata = metadata.except("import_email", "phone")
    self.metadata = metadata.merge("import_email" => @contact_email) if @contact_email.present?
    self.metadata = metadata.merge("phone" => @contact_phone) if @contact_phone.present?
  end

  def self.document_digest(document_number)
    BulkImportServices::UnitsImportValidationContext.document_digest(document_number)
  end

  def document_unique_within_organization
    return if document_number_digest.blank?

    scope = Person.where(
      organization_id: organization_id,
      document_type: document_type,
      document_number_digest: document_number_digest
    )
    scope = scope.where.not(id: id) if persisted?

    return unless scope.exists?

    errors.add(:document_number, "admin.people.validations.document_taken")
  end

  def email_unique_within_organization
    normalized = normalized_email_for_uniqueness
    return if normalized.blank?

    return unless email_taken_in_organization?(normalized)

    errors.add(:contact_email, "admin.people.validations.email_taken")
  end

  def normalized_email_for_uniqueness
    email = @contact_email.presence || metadata["import_email"].presence || user&.email
    email.to_s.downcase.strip.presence
  end

  def email_taken_in_organization?(normalized)
    metadata_scope = Person.where(organization_id: organization_id)
      .where("metadata->>'import_email' = ?", normalized)
    metadata_scope = metadata_scope.where.not(id: id) if persisted?
    return true if metadata_scope.exists?

    linked_user = User.where("LOWER(email) = ?", normalized).first
    return false unless linked_user

    existing = linked_user.person_for(organization)
    existing.present? && (!persisted? || existing.id != id)
  end

  def delete_tenant_roles
    return [] if roles.blank?

    tenant_roles = roles.select do |role|
      role.resource_type == "Organization" && role.resource_id == organization_id.to_s
    end

    role_names = tenant_roles.map(&:name)
    role_names.each { |name| remove_role(name, organization) }
    role_names
  end
end
