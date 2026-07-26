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

class VisitTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization

    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Visit Model Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
    @unit = Unit.create!(
      organization: @organization,
      residential_property: @property,
      identifier: "VISIT-MODEL-101",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
    @visitor = Person.create!(
      organization: @organization,
      display_name: "Visit Visitor",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "valid visit persists denormalized property and section from unit" do
    visit = build_visit

    assert visit.valid?
    assert_equal @property.id, visit.residential_property_id
    assert_nil visit.property_section_id
  end

  test "visit derives property from unit even when another property is assigned" do
    other_property = ResidentialProperty.create!(
      organization: @organization,
      name: "Other Visit Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )

    visit = build_visit
    visit.residential_property = other_property

    assert visit.valid?
    assert_equal @property.id, visit.residential_property_id
  end

  test "visit rejects valid_until before valid_from" do
    visit = build_visit(
      scheduled_at: 2.days.from_now,
      valid_from: 2.days.from_now,
      valid_until: 1.day.from_now
    )

    refute visit.valid?
    assert_includes visit.errors[:valid_until], I18n.t("activerecord.errors.models.visit.attributes.valid_until.after_valid_from")
  end

  test "visit rejects cross-organization visitor" do
    other_org = organizations(:two)
    other_visitor = ActsAsTenant.with_tenant(other_org) do
      Person.create!(
        organization: other_org,
        display_name: "Cross Org Visitor",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
    end

    visit = build_visit(visitor_person: other_visitor)

    refute visit.valid?
    assert visit.errors[:visitor_person].present?
  end

  test "visit status and visit_type must be allowed values" do
    visit = build_visit(status: "unknown", visit_type: "invalid")

    refute visit.valid?
    assert visit.errors[:status].present?
    assert visit.errors[:visit_type].present?
  end

  private

  def build_visit(**overrides)
    defaults = {
      organization: @organization,
      unit: @unit,
      visitor_person: @visitor,
      scheduled_at: 1.day.from_now,
      valid_from: 1.day.from_now,
      status: VisitStatuses::PENDING,
      visit_type: VisitTypes::GUEST
    }

    Visit.new(defaults.merge(overrides))
  end
end
