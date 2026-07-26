# frozen_string_literal: true

# Property staff assignment linking a canonical +Person+ to a +ResidentialProperty+.
#
# +Person+ is the only identity store per organization. This table records where
# and how someone works on a property; it does not create a separate staff
# identity. Operational staff flows (shifts, profile Staff tab, contextual badges)
# are not wired yet in the unified person profile change.
#
# Persistence contract (already migrated; no new tables required):
# - +person_id+ — required FK to +people+ (canonical identity)
# - +residential_property_id+ — required FK to +residential_properties+
# - +staff_type+ — required operational role on that property (+StaffTypes+;
#   OpenSpec refers to this concept as +staff_role+)
# - +status+, +starts_at+, +ends_at+ — assignment validity (same pattern as
#   ownerships/occupancies)
# - +organization_id+ — tenant scope; all queries must stay org-scoped
#
# Future integration points (not implemented in unified-person-profile):
# - +People::ContextualRoles+ staff badges (+concierge+, +property_admin+,
#   +cleaning_staff+) from active +staff_assignments+
# - +Admin::PeopleController#show+ +staff_assignments+ prop and Staff tab data
# - +Person::ProfileSummary#staff_assignments_count+
#
# == Schema Information
#
# Table name: staff_assignments
#
#  id                      :uuid             not null, primary key
#  confirmation_state      :string           default("confirmed"), not null
#  confirmed_at            :datetime
#  ends_at                 :date
#  metadata                :jsonb            not null
#  staff_type              :string           not null
#  starts_at               :date
#  status                  :string           default("active"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  organization_id         :uuid             not null
#  person_id               :uuid             not null
#  residential_property_id :uuid             not null
#
# Indexes
#
#  idx_on_organization_id_person_id_status_36b5c5bfed   (organization_id,person_id,status)
#  index_staff_assignments_on_confirmation_state        (confirmation_state)
#  index_staff_assignments_on_metadata                  (metadata) USING gin
#  index_staff_assignments_on_org_property_type_status  (organization_id,residential_property_id,staff_type,status)
#  index_staff_assignments_on_organization_id           (organization_id)
#  index_staff_assignments_on_person_id                 (person_id)
#  index_staff_assignments_on_residential_property_id   (residential_property_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (person_id => people.id)
#  fk_rails_...  (residential_property_id => residential_properties.id)
#
class StaffAssignment < ApplicationRecord
  include StaffTypes
  include TenantScopedAssociations

  acts_as_tenant :organization

  audited associated_with: :residential_property,
          only: %i[status staff_type starts_at ends_at person_id residential_property_id]

  STATUS_ACTIVE = "active"
  STATUS_INACTIVE = "inactive"
  STATUSES = [ STATUS_ACTIVE, STATUS_INACTIVE ].freeze

  # Operational roles are confirmable: an assignment created through onboarding
  # starts +pending+ and grants no access until the holder confirms it. The DB
  # column defaults to +confirmed+ so legacy and non-onboarding rows keep working;
  # Authorization::Resolver enforcement of confirmed-only roles is deferred
  # (tasks §16.2/§17).
  CONFIRMATION_PENDING = "pending"
  CONFIRMATION_CONFIRMED = "confirmed"
  CONFIRMATION_STATES = [ CONFIRMATION_PENDING, CONFIRMATION_CONFIRMED ].freeze

  belongs_to :organization
  belongs_to :person
  belongs_to :residential_property

  validates :staff_type, presence: true, inclusion: { in: StaffTypes::ALL }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :confirmation_state, presence: true, inclusion: { in: CONFIRMATION_STATES }
  validate :ends_at_not_before_starts_at

  validates_same_tenant :person, :residential_property

  has_many :staff_shifts, dependent: :restrict_with_error

  scope :active, -> { where(status: STATUS_ACTIVE) }
  scope :currently_active, ->(at: Date.current) {
    active
      .where("starts_at IS NULL OR starts_at <= ?", at)
      .where("ends_at IS NULL OR ends_at >= ?", at)
  }
  scope :for_property, ->(property) { where(residential_property: property) }
  scope :for_person, ->(person) { where(person: person) }
  scope :confirmed, -> { where(confirmation_state: CONFIRMATION_CONFIRMED) }
  scope :pending_confirmation, -> { where(confirmation_state: CONFIRMATION_PENDING) }

  def confirmed?
    confirmation_state == CONFIRMATION_CONFIRMED
  end

  def confirm!
    update!(confirmation_state: CONFIRMATION_CONFIRMED, confirmed_at: Time.current)
  end

  private

  def ends_at_not_before_starts_at
    return unless starts_at.present? && ends_at.present?

    errors.add(:ends_at, :before_starts_at, message: "must be on or after starts_at") if ends_at < starts_at
  end
end
