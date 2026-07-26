# frozen_string_literal: true

# == Schema Information
#
# Table name: visit_status_histories
#
#  id                   :uuid             not null, primary key
#  event_type           :string           not null
#  from_status          :string
#  metadata             :jsonb            not null
#  notes                :text
#  occurred_at          :datetime         not null
#  reason               :text
#  to_status            :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  changed_by_id        :uuid
#  changed_by_person_id :uuid
#  organization_id      :uuid             not null
#  visit_id             :uuid             not null
#
# Indexes
#
#  index_visit_status_histories_on_changed_by_id                  (changed_by_id)
#  index_visit_status_histories_on_changed_by_person_id           (changed_by_person_id)
#  index_visit_status_histories_on_metadata                       (metadata) USING gin
#  index_visit_status_histories_on_org_event_type                 (organization_id,event_type)
#  index_visit_status_histories_on_org_visit_created_at           (organization_id,visit_id,created_at)
#  index_visit_status_histories_on_org_visit_occurred_at          (organization_id,visit_id,occurred_at)
#  index_visit_status_histories_on_organization_id                (organization_id)
#  index_visit_status_histories_on_organization_id_and_to_status  (organization_id,to_status)
#  index_visit_status_histories_on_visit_id                       (visit_id)
#
# Foreign Keys
#
#  fk_rails_...  (changed_by_id => users.id)
#  fk_rails_...  (changed_by_person_id => people.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (visit_id => visits.id)
#
class VisitStatusHistory < ApplicationRecord
  include TenantScopedAssociations
  include VisitEventTypes
  include VisitStatuses

  acts_as_tenant :organization

  belongs_to :organization
  belongs_to :visit
  belongs_to :actor_user, class_name: "User", foreign_key: :changed_by_id, optional: true
  belongs_to :changed_by_person, class_name: "Person", optional: true

  alias_attribute :actor_user_id, :changed_by_id

  validates :event_type, presence: true, inclusion: { in: VisitEventTypes::ALL }
  validates :to_status, presence: true, inclusion: { in: VisitStatuses::ALL }
  validates :from_status, inclusion: { in: VisitStatuses::ALL }, allow_nil: true
  validates :occurred_at, presence: true

  validates_same_tenant :visit, :actor_user, :changed_by_person

  validate :organization_matches_visit

  before_validation :sanitize_metadata_assignment

  scope :chronological, -> { order(occurred_at: :asc, created_at: :asc) }
  scope :for_visit, ->(visit) { where(visit_id: visit.id) }

  private

  def organization_matches_visit
    return if visit.blank? || organization_id.blank?
    return if organization_id == visit.organization_id

    errors.add(:organization, :incoherent_with_visit)
  end

  def sanitize_metadata_assignment
    self.metadata = Visit.sanitize_metadata(metadata)
  end
end
