# == Schema Information
#
# Table name: organizations
#
#  id                        :uuid             not null, primary key
#  country_code              :string           default("CL"), not null
#  deleted_at                :datetime
#  legal_name                :string
#  metadata                  :jsonb            not null
#  name                      :string           not null
#  plan                      :string           default("free"), not null
#  settings                  :jsonb            not null
#  status                    :string           default("active"), not null
#  subdomain                 :string
#  tax_identifier_ciphertext :text
#  tax_identifier_digest     :string
#  tax_identifier_type       :string           default("rut"), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  idx_organizations_unique_tax_identifier  (country_code,tax_identifier_type,tax_identifier_digest) UNIQUE WHERE ((tax_identifier_digest IS NOT NULL) AND (deleted_at IS NULL))
#  index_organizations_on_deleted_at        (deleted_at)
#  index_organizations_on_metadata          (metadata) USING gin
#  index_organizations_on_plan              (plan)
#  index_organizations_on_settings          (settings) USING gin
#  index_organizations_on_status            (status)
#  index_organizations_on_subdomain         (subdomain) UNIQUE
#
class Organization < ApplicationRecord
  acts_as_paranoid
  resourcify

  PLAN_FREE = "free".freeze
  PLAN_PRO = "pro".freeze
  PLAN_ENTERPRISE = "enterprise".freeze

  enum :plan, {
    free: PLAN_FREE,
    pro: PLAN_PRO,
    enterprise: PLAN_ENTERPRISE
  }, validate: true

  has_many :people, dependent: :destroy
  has_many :organization_memberships, dependent: :destroy
  has_many :users, through: :people
  has_many :residential_properties, dependent: :destroy
  has_many :unit_ownerships, dependent: :destroy
  has_many :lease_contracts, dependent: :destroy
  has_many :unit_occupancies, dependent: :destroy
  has_many :authorized_residents, dependent: :destroy
  has_many :visits, dependent: :destroy
  has_many :roles
  has_one_attached :logo
  has_one_attached :cover

  before_validation :assign_default_plan, on: :create

  before_validation :generate_uuid, on: :create

  validates :plan, presence: true
  validates :plan, inclusion: { in: plans.keys }

  def cover_path
    BlobUrls.url_for(cover)
  end

  def logo_path
    BlobUrls.url_for(logo)
  end

  def users_count
    people.where.not(user_id: nil).distinct.count(:user_id)
  end

  def self.ransackable_attributes(auth_object = nil)
    [ "name", "plan" ]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end

  private

  def generate_uuid
    self.id ||= SecureRandom.uuid
  end

  def assign_default_plan
    self.plan ||= PLAN_FREE
  end
end
