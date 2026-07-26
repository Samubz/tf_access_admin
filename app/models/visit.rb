# frozen_string_literal: true

# == Schema Information
#
# Table name: visits
#
#  id                      :uuid             not null, primary key
#  authorized_at           :datetime
#  checked_in_at           :datetime
#  checked_out_at          :datetime
#  metadata                :jsonb            not null
#  notes                   :text
#  notification_status     :string           default("pending"), not null
#  scheduled_at            :datetime         not null
#  status                  :string           default("pending"), not null
#  valid_from              :datetime         not null
#  valid_until             :datetime
#  visit_type              :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  authorized_by_id        :uuid
#  checked_in_by_id        :uuid
#  checked_out_by_id       :uuid
#  created_by_id           :uuid
#  organization_id         :uuid             not null
#  property_section_id     :uuid
#  residential_property_id :uuid             not null
#  unit_id                 :uuid             not null
#  visitor_person_id       :uuid             not null
#
# Indexes
#
#  index_visits_on_authorized_by_id                   (authorized_by_id)
#  index_visits_on_checked_in_by_id                   (checked_in_by_id)
#  index_visits_on_checked_out_by_id                  (checked_out_by_id)
#  index_visits_on_created_by_id                      (created_by_id)
#  index_visits_on_metadata                           (metadata) USING gin
#  index_visits_on_org_property_operational_statuses  (organization_id,residential_property_id,status,checked_out_at) WHERE ((status)::text = ANY (ARRAY[('authorized'::character varying)::text, ('checked_in'::character varying)::text, ('checked_out'::character varying)::text]))
#  index_visits_on_org_property_pending_scheduled_at  (organization_id,residential_property_id,scheduled_at) WHERE ((status)::text = 'pending'::text)
#  index_visits_on_org_property_status_scheduled_at   (organization_id,residential_property_id,status,scheduled_at)
#  index_visits_on_org_unit_scheduled_at              (organization_id,unit_id,scheduled_at)
#  index_visits_on_organization_id                    (organization_id)
#  index_visits_on_property_section_id                (property_section_id)
#  index_visits_on_residential_property_id            (residential_property_id)
#  index_visits_on_unit_id                            (unit_id)
#  index_visits_on_visitor_person_id                  (visitor_person_id)
#
# Foreign Keys
#
#  fk_rails_...  (authorized_by_id => users.id)
#  fk_rails_...  (checked_in_by_id => users.id)
#  fk_rails_...  (checked_out_by_id => users.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (property_section_id => property_sections.id)
#  fk_rails_...  (residential_property_id => residential_properties.id)
#  fk_rails_...  (unit_id => units.id)
#  fk_rails_...  (visitor_person_id => people.id)
#
class Visit < ApplicationRecord
  include TenantScopedAssociations
  include VisitStatuses
  include VisitTypes
  include Visit::NotificationStatuses
  include Visit::OperationalMetadata
  include Visit::StateMachine

  acts_as_tenant :organization

  audited only: %i[
    status visit_type scheduled_at valid_from valid_until notes
    visitor_person_id unit_id residential_property_id property_section_id
    created_by_id authorized_by_id authorized_at
    checked_in_by_id checked_in_at checked_out_by_id checked_out_at
    notification_status
  ]

  validates :notification_status, presence: true, inclusion: { in: Visit::NotificationStatuses::ALL }

  belongs_to :organization
  belongs_to :residential_property
  belongs_to :property_section, optional: true
  belongs_to :unit
  belongs_to :visitor_person, class_name: "Person"
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :authorized_by, class_name: "User", optional: true
  belongs_to :checked_in_by, class_name: "User", optional: true
  belongs_to :checked_out_by, class_name: "User", optional: true
  belongs_to :staff_shift, optional: true

  has_many :visit_status_histories, -> { chronological }, dependent: :destroy
  has_many :visit_participants
  has_many :notifications, as: :notifiable, dependent: :destroy
  has_one  :visit_recurrence, dependent: :destroy

  validates :scheduled_at, :valid_from, presence: true
  validates :status, presence: true, inclusion: { in: VisitStatuses::ALL }
  validates :visit_type, presence: true, inclusion: { in: VisitTypes::ALL }

  validates_same_tenant :residential_property, :property_section, :unit,
                        :visitor_person,
                        :created_by, :authorized_by, :checked_in_by, :checked_out_by,
                        :staff_shift

  validate :validity_range_coherent
  validate :location_coherent_with_unit

  before_validation :denormalize_location_from_unit
  before_validation :assign_validity_defaults
  before_validation :sanitize_metadata_assignment

  # Window during which a checked-out visit is still surfaced in operational
  # (concierge) listings as a "recent" check-out.
  RECENT_CHECK_OUT_WINDOW = 24.hours

  scope :operational, -> { where(status: VisitStatuses::OPERATIONAL) }

  # Recently checked-out visits, used to keep just-completed visits visible in
  # operational listings without exposing the full historical backlog.
  scope :recently_checked_out, ->(window: RECENT_CHECK_OUT_WINDOW) {
    where(status: VisitStatuses::CHECKED_OUT).where(checked_out_at: window.ago..)
  }

  # Visits visible to concierge-style operational actors: currently authorized,
  # currently checked-in, or recently checked-out. Pending and cancelled visits
  # are intentionally excluded (OpenSpec visit-management §5.5).
  scope :concierge_visible, -> {
    where(
      "visits.status IN (:operational_now) OR (visits.status = :checked_out AND visits.checked_out_at >= :since)",
      operational_now: [ VisitStatuses::AUTHORIZED, VisitStatuses::CHECKED_IN ],
      checked_out: VisitStatuses::CHECKED_OUT,
      since: RECENT_CHECK_OUT_WINDOW.ago
    )
  }

  # 1.5 — Authorized visits whose scheduling or validity window intersects the
  # local calendar day. Uses the application time zone when none is supplied.
  # A visit with no valid_until is treated as valid for the full day.
  # Ordered by scheduled_at asc so the closest upcoming visits appear first (2.7).
  scope :expected_today, ->(time_zone: Time.zone) {
    tz        = time_zone.is_a?(String) ? ActiveSupport::TimeZone[time_zone] : (time_zone || Time.zone)
    day_start = tz.now.beginning_of_day
    day_end   = tz.now.end_of_day
    where(status: VisitStatuses::AUTHORIZED)
      .where(
        "(visits.scheduled_at BETWEEN :start AND :finish) OR " \
        "(visits.valid_from <= :finish AND (visits.valid_until IS NULL OR visits.valid_until >= :start))",
        start: day_start,
        finish: day_end
      )
      .order(scheduled_at: :asc)
  }

  # 1.6 — Visits currently inside the property: checked-in with no recorded exit.
  # Ordered by checked_in_at asc so prolonged stays are visible first (2.7).
  scope :currently_inside, -> {
    where(status: VisitStatuses::CHECKED_IN, checked_out_at: nil)
      .order(checked_in_at: :asc)
  }

  # 2.1 — Exact document search via blind-index digest, scoped to the organization.
  # Joining visitor_person ensures cross-org isolation regardless of base scope.
  scope :by_visitor_document, ->(raw_doc, organization:) {
    return none if raw_doc.blank?
    digest = Person.document_digest(raw_doc.to_s.strip)
    return none if digest.blank?
    joins(:visitor_person).where(
      people: { organization_id: organization.id, document_number_digest: digest }
    )
  }

  # 1.7 — True when the visit is authorized but its valid_until has lapsed,
  # making it operationally expired without a persisted state transition.
  # Use this for display logic; never mutate status based solely on this predicate.
  def authorization_expired?
    status == VisitStatuses::AUTHORIZED && valid_until.present? && valid_until < Time.zone.now
  end

  # Effective operational status for display: maps a lapsed authorization to the
  # calculated `expired` label without persisting a transition (1.7). Concierge
  # serializers expose this alongside the persisted `status`.
  def effective_operational_status
    return VisitStatuses::EXPIRED if authorization_expired?

    status
  end

  # Elapsed time inside the property, in seconds. For an active stay it runs to
  # now; for a completed visit it spans entry to exit. Nil until checked in.
  # No persisted column is needed (computed from timestamps).
  def duration_seconds
    return nil if checked_in_at.blank?

    (checked_out_at || Time.zone.now).to_i - checked_in_at.to_i
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[status visit_type scheduled_at authorized_at checked_in_at checked_out_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[visitor_person unit]
  end

  private

  def denormalize_location_from_unit
    return if unit.blank?

    self.organization_id ||= unit.organization_id
    self.residential_property_id = unit.residential_property_id
    self.property_section_id = unit.property_section_id
  end

  def assign_validity_defaults
    self.visit_type = VisitTypes::GUEST if visit_type.blank?
    self.valid_from ||= scheduled_at
  end

  def sanitize_metadata_assignment
    self.metadata = self.class.sanitize_metadata(metadata)
  end

  def validity_range_coherent
    return if valid_until.blank? || valid_from.blank?
    return if valid_until >= valid_from

    errors.add(:valid_until, :after_valid_from)
  end

  def location_coherent_with_unit
    return if unit.blank?

    if residential_property_id.present? && residential_property_id != unit.residential_property_id
      errors.add(:residential_property, :incoherent_with_unit)
    end

    section_matches = property_section_id == unit.property_section_id
    section_matches ||= property_section_id.blank? && unit.property_section_id.blank?
    return if section_matches

    errors.add(:property_section, :incoherent_with_unit)
  end
end
