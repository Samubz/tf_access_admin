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
require "test_helper"

# §7.11 — Verifies that:
# - Admin::VisitDetailSerializer (full detail) includes all administrative fields.
# - Admin::VisitRestrictedSerializer omits notes, metadata, actors, history.
# - Concierge::VisitSummarySerializer omits administrative fields.
# - permissions/actions are consistent across serializers.
class VisitSerializerTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @property = create_property(@organization, "Ser Test Property")
    @unit = create_unit(@property, "SER-101")

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "ser-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @concierge = create_staff_user(
      organization: @organization,
      email: "ser-concierge@example.test",
      staff_type: StaffTypes::CONCIERGE,
      property: @property
    )
    @owner = create_owner_user(
      organization: @organization,
      email: "ser-owner@example.test",
      unit: @unit
    )

    @authorizer_person = @owner.person_for(@organization)
    UnitOccupancy.create!(
      organization: @organization,
      person: @authorizer_person,
      unit: @unit,
      occupancy_type: OccupancyTypes::OWNER_RESIDENT,
      can_authorize_visits: true,
      starts_at: Date.current,
      status: OccupancyStatuses::ACTIVE
    )
    visitor_person = Person.create!(
      organization: @organization,
      display_name: "Ser Test Visitor",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )

    @visit = ActsAsTenant.with_tenant(@organization) do
      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: visitor_person,
        scheduled_at: 1.day.from_now,
        valid_from: 1.day.from_now,
        visit_type: VisitTypes::GUEST,
        status: VisitStatuses::AUTHORIZED,
        authorized_at: 10.minutes.ago,
        authorized_by_id: @tenant_admin.id,
        notes: "Some admin note"
      )
    end

    @visit.visit_status_histories.create!(
      organization: @organization,
      event_type: VisitEventTypes::AUTHORIZED,
      from_status: VisitStatuses::PENDING,
      to_status: VisitStatuses::AUTHORIZED,
      occurred_at: 10.minutes.ago,
      changed_by_id: @tenant_admin.id
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  # ─── Admin::VisitSerializer (list) ───────────────────────────────────────────

  test "admin list serializer includes visitor/authorizers/unit summary and labels" do
    data = Admin::VisitSerializer.new(@visit, current_user: @tenant_admin).as_json

    assert_equal @visit.id, data[:id]
    assert data[:status_label].present?
    assert data[:visit_type_label].present?
    assert_equal @visit.visitor_person.display_name, data[:visitor][:display_name]
    assert_includes data[:authorizers].map { |a| a[:display_name] }, @authorizer_person.display_name
    assert_equal @unit.identifier, data[:unit][:identifier]
  end

  test "admin list serializer returns an empty authorizers list when the unit has no active authorizer" do
    empty_unit = create_unit(@property, "SER-102")
    other_visitor = Person.create!(
      organization: @organization,
      display_name: "Ser Test Visitor 2",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    unassigned_visit = ActsAsTenant.with_tenant(@organization) do
      Visit.create!(
        organization: @organization,
        unit: empty_unit,
        visitor_person: other_visitor,
        scheduled_at: 1.day.from_now,
        valid_from: 1.day.from_now,
        visit_type: VisitTypes::GUEST,
        status: VisitStatuses::PENDING
      )
    end

    data = Admin::VisitSerializer.new(unassigned_visit, current_user: @tenant_admin).as_json

    assert_empty data[:authorizers]
  end

  test "admin list serializer includes permissions and actions" do
    data = Admin::VisitSerializer.new(@visit, current_user: @tenant_admin).as_json

    assert data[:permissions].key?(:show)
    assert data[:permissions].key?(:authorize)
    assert data[:permissions].key?(:check_in)
    assert_includes data[:actions], "show"
  end

  # ─── Admin::VisitDetailSerializer (full detail) ──────────────────────────────

  test "full detail serializer includes notes, metadata, actors, and history" do
    data = Admin::VisitDetailSerializer.new(@visit, current_user: @tenant_admin).as_json

    assert_equal "Some admin note", data[:notes]
    assert data.key?(:metadata)
    assert_equal @tenant_admin.id, data[:authorized_by_id]
    assert_equal @tenant_admin.name, data[:authorized_by_actor][:name]
    assert_equal 1, data[:history].length
    assert_equal VisitEventTypes::AUTHORIZED, data[:history].first[:event_type]
  end

  test "full detail serializer includes full visitor profile" do
    data = Admin::VisitDetailSerializer.new(@visit, current_user: @tenant_admin).as_json

    assert data[:visitor_detail].key?(:document_type)
  end

  # ─── Admin::VisitRestrictedSerializer (restricted detail) ────────────────────

  test "restricted serializer omits notes, metadata, and actors but includes history" do
    data = Admin::VisitRestrictedSerializer.new(@visit, current_user: @concierge).as_json

    assert_nil data[:notes]
    assert_nil data[:metadata]
    assert_nil data[:authorized_by_actor]
    assert_nil data[:visitor_detail]
    assert_equal 1, data[:history].length
    assert_equal VisitEventTypes::AUTHORIZED, data[:history].first[:event_type]
  end

  test "restricted serializer still includes visitor/authorizers/unit and status" do
    data = Admin::VisitRestrictedSerializer.new(@visit, current_user: @concierge).as_json

    assert_equal @visit.visitor_person.display_name, data[:visitor][:display_name]
    assert_equal @unit.identifier, data[:unit][:identifier]
    assert data[:status_label].present?
  end

  test "restricted permissions do not include create, update, authorize, cancel" do
    data = Admin::VisitRestrictedSerializer.new(@visit, current_user: @concierge).as_json

    refute data[:permissions].key?(:create)
    refute data[:permissions].key?(:authorize)
    refute data[:permissions].key?(:cancel)
  end

  # ─── Admin::VisitContextualDetailSerializer (contextual detail) ─────────────

  test "contextual detail serializer includes limited person detail, notes, metadata, and history" do
    data = Admin::VisitContextualDetailSerializer.new(@visit, current_user: @owner).as_json

    assert_equal "Some admin note", data[:notes]
    assert data.key?(:metadata)
    assert_equal @visit.visitor_person.display_name, data[:visitor_detail][:display_name]
    assert_nil data[:authorized_by_actor]
    assert_equal 1, data[:history].length
    assert data[:contextual_detail]
  end

  test "contextual permissions include create, authorize, and cancel without full detail" do
    pending_visit = ActsAsTenant.with_tenant(@organization) do
      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: @visit.visitor_person,
        scheduled_at: 1.day.from_now,
        valid_from: 1.day.from_now,
        status: VisitStatuses::PENDING
      )
    end

    data = Admin::VisitContextualDetailSerializer.new(pending_visit, current_user: @owner).as_json

    assert data[:permissions][:show]
    assert data[:permissions][:create]
    assert data[:permissions][:authorize]
    assert data[:permissions][:cancel]
    refute data[:permissions][:full_detail]
    refute data[:permissions][:restricted_detail]
    assert data[:permissions][:contextual_detail]
  end

  # ─── Concierge::VisitSummarySerializer ───────────────────────────────────────

  test "concierge summary omits notes, metadata, history, and actor stamps" do
    data = Concierge::VisitSummarySerializer.new(@visit, current_user: @concierge).as_json

    assert_nil data[:notes]
    assert_nil data[:metadata]
    assert_nil data[:history]
    assert_nil data[:authorized_by_actor]
  end

  test "concierge summary exposes visitor, authorizers, unit and permitted actions" do
    data = Concierge::VisitSummarySerializer.new(@visit, current_user: @concierge).as_json

    assert data[:visitor][:display_name].present?
    assert data[:authorizers].any? { |a| a[:display_name].present? }
    assert data[:unit][:identifier].present?
    assert data[:permissions][:check_in]
    assert_includes data[:actions], "check_in"
  end

  # ─── Actions consistency ─────────────────────────────────────────────────────

  test "actions array is derived from permissions (no false entries)" do
    data = Admin::VisitSerializer.new(@visit, current_user: @tenant_admin).as_json
    perms = data[:permissions]
    actions = data[:actions]

    allowed_keys = perms.filter_map { |k, v| k.to_s if v }
    assert_equal allowed_keys.sort, actions.sort
  end
end
