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
require "test_helper"

class VisitStatusHistoryTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @property = create_property(@organization, "History Model Property")
    @unit = create_unit(@property, "HIST-MODEL-101")
    @host = Person.create!(
      organization: @organization,
      display_name: "History Host",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @visitor = Person.create!(
      organization: @organization,
      display_name: "History Visitor",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    UnitOwnership.create!(
      organization: @organization,
      person: @host,
      unit: @unit,
      ownership_percentage: 100,
      starts_at: Date.current,
      status: UnitOwnership::STATUS_ACTIVE
    )
    @actor = create_user_for_organization(
      organization: @organization,
      email: "history-model-actor@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @visit = Visit.create!(
      organization: @organization,
      unit: @unit,
      visitor_person: @visitor,
      scheduled_at: 1.day.from_now,
      valid_from: 1.day.from_now,
      status: VisitStatuses::PENDING,
      visit_type: VisitTypes::GUEST
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "valid history persists MVP contract fields" do
    occurred_at = Time.zone.parse("2026-06-19 10:00:00")
    history = VisitStatusHistory.create!(
      organization: @organization,
      visit: @visit,
      event_type: VisitEventTypes::CREATED,
      from_status: nil,
      to_status: VisitStatuses::PENDING,
      actor_user: @actor,
      occurred_at: occurred_at,
      notes: "Visit created",
      metadata: {
        "check_in" => {
          "access_point" => "Main gate",
          "access_type" => VisitAccessTypes::PEDESTRIAN,
          "unexpected" => "drop"
        }
      }
    )

    assert_equal @visit.id, history.visit_id
    assert_equal @organization.id, history.organization_id
    assert_equal VisitEventTypes::CREATED, history.event_type
    assert_nil history.from_status
    assert_equal VisitStatuses::PENDING, history.to_status
    assert_equal @actor.id, history.actor_user_id
    assert_equal occurred_at, history.occurred_at
    assert_equal "Visit created", history.notes
    assert_equal VisitAccessTypes::PEDESTRIAN, history.metadata.dig("check_in", "access_type")
    refute history.metadata.dig("check_in", "unexpected")
  end

  test "chronological scope orders by occurred_at then created_at" do
    first = VisitStatusHistory.create!(
      organization: @organization,
      visit: @visit,
      event_type: VisitEventTypes::CREATED,
      to_status: VisitStatuses::PENDING,
      actor_user: @actor,
      occurred_at: 2.hours.ago
    )
    second = VisitStatusHistory.create!(
      organization: @organization,
      visit: @visit,
      event_type: VisitEventTypes::AUTHORIZED,
      from_status: VisitStatuses::PENDING,
      to_status: VisitStatuses::AUTHORIZED,
      actor_user: @actor,
      occurred_at: 1.hour.ago
    )

    ordered = @visit.visit_status_histories.chronological.to_a

    assert_equal [ first.id, second.id ], ordered.map(&:id)
  end

  test "rejects cross-organization visit reference" do
    other_org = organizations(:two)
    other_visit = ActsAsTenant.with_tenant(other_org) do
      other_property = create_property(other_org, "Other History Property")
      other_unit = create_unit(other_property, "OTH-HIST-101")
      other_host = Person.create!(
        organization: other_org,
        display_name: "Other Host",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      other_visitor = Person.create!(
        organization: other_org,
        display_name: "Other Visitor",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      UnitOwnership.create!(
        organization: other_org,
        person: other_host,
        unit: other_unit,
        ownership_percentage: 100,
        starts_at: Date.current,
        status: UnitOwnership::STATUS_ACTIVE
      )
      Visit.create!(
        organization: other_org,
        unit: other_unit,
        visitor_person: other_visitor,
        scheduled_at: 1.day.from_now,
        valid_from: 1.day.from_now,
        status: VisitStatuses::PENDING,
        visit_type: VisitTypes::GUEST
      )
    end

    history = VisitStatusHistory.new(
      organization: @organization,
      visit: other_visit,
      event_type: VisitEventTypes::CREATED,
      to_status: VisitStatuses::PENDING,
      actor_user: @actor,
      occurred_at: Time.zone.now
    )

    refute history.valid?
    assert history.errors[:organization].present?
  end
end
