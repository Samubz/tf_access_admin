# frozen_string_literal: true

require "test_helper"

class Person::ChangeHistoryTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @user = users(:one)
    @user.update_columns(name: "History Admin")

    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Person History Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
    @unit = Unit.create!(
      organization: @organization,
      residential_property: @property,
      identifier: "HIST-101",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
    @person = Person.without_auditing do
      Person.create!(
        organization: @organization,
        display_name: "History Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
    end
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "combines person ownership and occupancy audits" do
    ownership = UnitOwnership.without_auditing do
      UnitOwnership.create!(
        organization: @organization,
        unit: @unit,
        person: @person,
        ownership_percentage: 100,
        starts_at: Date.current,
        status: UnitOwnership::STATUS_ACTIVE
      )
    end
    occupancy = UnitOccupancy.without_auditing do
      UnitOccupancy.create!(
        organization: @organization,
        unit: @unit,
        person: @person,
        occupancy_type: OccupancyTypes::TENANT,
        starts_at: Time.current,
        status: OccupancyStatuses::ACTIVE
      )
    end

    person_audit = TenantAudit.create!(
      organization: @organization,
      auditable: @person,
      user: @user,
      action: "update",
      audited_changes: { "display_name" => [ "Old", "History Person" ] },
      version: 2,
      created_at: Time.zone.parse("2026-06-10 12:00:00")
    )
    ownership_audit = TenantAudit.create!(
      organization: @organization,
      auditable: ownership,
      associated: @unit,
      user: @user,
      action: "create",
      audited_changes: {
        "ownership_percentage" => [ nil, 100 ],
        "person_id" => [ nil, @person.id ]
      },
      version: 1,
      created_at: Time.zone.parse("2026-06-12 12:00:00")
    )
    occupancy_audit = TenantAudit.create!(
      organization: @organization,
      auditable: occupancy,
      associated: @unit,
      user: @user,
      action: "create",
      audited_changes: {
        "occupancy_type" => [ nil, OccupancyTypes::TENANT ],
        "person_id" => [ nil, @person.id ]
      },
      version: 1,
      created_at: Time.zone.parse("2026-06-11 12:00:00")
    )

    entries = Person::ChangeHistory.for(@person)

    assert_equal [ ownership_audit.id, occupancy_audit.id, person_audit.id ], entries.map { |entry| entry[:id] }
    assert entries.all? { |entry| entry[:occurred_at].present? && entry[:description].present? }
    assert entries.all? { |entry| entry[:source_type].present? && entry[:source_id].present? }
  end

  test "orders history from newest to oldest" do
    older = TenantAudit.create!(
      organization: @organization,
      auditable: @person,
      user: @user,
      action: "create",
      audited_changes: { "display_name" => [ nil, "History Person" ] },
      version: 1,
      created_at: Time.zone.parse("2026-06-01 10:00:00")
    )
    newer = TenantAudit.create!(
      organization: @organization,
      auditable: @person,
      user: @user,
      action: "update",
      audited_changes: { "status" => [ PersonStatuses::ACTIVE, PersonStatuses::INACTIVE ] },
      version: 2,
      created_at: Time.zone.parse("2026-06-15 10:00:00")
    )

    entries = Person::ChangeHistory.for(@person)

    assert_equal [ newer.id, older.id ], entries.map { |entry| entry[:id] }
  end
end
