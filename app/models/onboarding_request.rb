# frozen_string_literal: true

# Request to invite a person without an account or incorporate an existing
# account into a new organization, property, or unit. A single concept covers
# both cases; +user_id+ distinguishes an incorporation of an existing account
# from an invitation to create one (spec: property-onboarding).
#
# Policy, controllers, and the acceptance/activation flow are wired in a later
# slice (tasks §7/§18); this model provides the persistence contract only.
#
# == Schema Information
#
# Table name: onboarding_requests
#
#  id                      :uuid             not null, primary key
#  conflict_reason         :string
#  deleted_at              :datetime
#  expires_at              :datetime         not null
#  metadata                :jsonb            not null
#  requested_relationship  :string           not null
#  requested_roles         :jsonb            not null
#  status                  :string           default("pending"), not null
#  token_digest            :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  organization_id         :uuid             not null
#  person_id               :uuid
#  requested_by_person_id  :uuid
#  residential_property_id :uuid
#  unit_id                 :uuid
#  user_id                 :uuid
#
# Indexes
#
#  idx_onboarding_requests_unique_pending_scope          (organization_id,person_id,requested_relationship,residential_property_id,unit_id) UNIQUE WHERE (((status)::text = 'pending'::text) AND (deleted_at IS NULL))
#  idx_onboarding_requests_unique_token_digest           (token_digest) UNIQUE WHERE (token_digest IS NOT NULL)
#  index_onboarding_requests_on_deleted_at               (deleted_at)
#  index_onboarding_requests_on_organization_id          (organization_id)
#  index_onboarding_requests_on_person_id                (person_id)
#  index_onboarding_requests_on_requested_by_person_id   (requested_by_person_id)
#  index_onboarding_requests_on_residential_property_id  (residential_property_id)
#  index_onboarding_requests_on_status                   (status)
#  index_onboarding_requests_on_unit_id                  (unit_id)
#  index_onboarding_requests_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (person_id => people.id)
#  fk_rails_...  (requested_by_person_id => people.id)
#  fk_rails_...  (residential_property_id => residential_properties.id)
#  fk_rails_...  (unit_id => units.id)
#  fk_rails_...  (user_id => users.id)
#
class OnboardingRequest < ApplicationRecord
  include TenantScopedAssociations

  acts_as_tenant :organization
  acts_as_paranoid

  audited only: %i[status requested_relationship conflict_reason expires_at]

  RELATIONSHIP_MEMBERSHIP      = "membership"
  RELATIONSHIP_PROPERTY_ACCESS = "property_access"
  RELATIONSHIP_OWNERSHIP       = "ownership"
  RELATIONSHIP_OCCUPANCY       = "occupancy"
  RELATIONSHIP_STAFF           = "staff"

  RELATIONSHIPS = [
    RELATIONSHIP_MEMBERSHIP,
    RELATIONSHIP_PROPERTY_ACCESS,
    RELATIONSHIP_OWNERSHIP,
    RELATIONSHIP_OCCUPANCY,
    RELATIONSHIP_STAFF
  ].freeze

  STATUS_PENDING  = "pending"
  STATUS_ACCEPTED = "accepted"
  STATUS_REJECTED = "rejected"
  STATUS_EXPIRED  = "expired"
  STATUS_REVOKED  = "revoked"
  STATUS_CONFLICT = "conflict"

  STATUSES = [
    STATUS_PENDING,
    STATUS_ACCEPTED,
    STATUS_REJECTED,
    STATUS_EXPIRED,
    STATUS_REVOKED,
    STATUS_CONFLICT
  ].freeze

  belongs_to :organization
  belongs_to :residential_property, optional: true
  belongs_to :unit, optional: true
  belongs_to :person, optional: true
  belongs_to :user, optional: true
  belongs_to :requested_by_person, class_name: "Person", optional: true

  validates :requested_relationship, presence: true, inclusion: { in: RELATIONSHIPS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :expires_at, presence: true

  validates_same_tenant :residential_property, :unit, :person, :requested_by_person

  scope :pending, -> { where(status: STATUS_PENDING) }

  include AASM

  aasm column: :status, whiny_persistence: true do
    state :pending, initial: true
    state :accepted
    state :rejected
    state :expired
    state :revoked
    state :conflict

    event :accept do
      transitions from: :pending, to: :accepted
    end

    event :reject do
      transitions from: :pending, to: :rejected
    end

    event :expire do
      transitions from: :pending, to: :expired
    end

    event :revoke do
      transitions from: %i[pending conflict], to: :revoked
    end

    event :flag_conflict do
      transitions from: :pending, to: :conflict
    end
  end
end
