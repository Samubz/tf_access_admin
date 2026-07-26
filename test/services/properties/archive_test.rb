# frozen_string_literal: true

require "test_helper"

# Properties::Archive domain service (improve-property-foundation §7).
# Archiving is non-destructive: it only flips status and must preserve the whole
# dependency graph (sections, units, persons, staff assignments, visits).
class Properties::ArchiveTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "prop-archive-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @property = create_property(@organization, "Archive Target")

    @section = PropertySection.create!(
      organization: @organization,
      residential_property: @property,
      name: "Tower A",
      section_type: SectionTypes::TOWER
    )
    @unit = create_unit(@property, "ARCH-101")

    # Person related through staff assignment.
    @staff_user = create_staff_user(
      organization: @organization,
      email: "prop-archive-staff@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )
    @staff_assignment = StaffAssignment.find_by(
      organization: @organization,
      person: @staff_user.person_for(@organization),
      residential_property: @property
    )

    # Person related through ownership (also serves as the visit host).
    @owner = create_owner_user(
      organization: @organization,
      email: "prop-archive-owner@example.test",
      unit: @unit
    )
    visitor = Person.create!(
      organization: @organization,
      display_name: "Archive Visitor",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @visit = Visit.create!(
      organization: @organization,
      unit: @unit,
      visitor_person: visitor,
      scheduled_at: 1.day.from_now,
      valid_from: 1.day.from_now,
      status: VisitStatuses::PENDING
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  # 7.11 + 7.8 + 7.9 + 7.10 ---------------------------------------------------
  test "7.11 archives the property without destroying any dependency" do
    result = Properties::Archive.call(actor: @tenant_admin, property: @property)

    assert result.success?
    @property.reload
    assert_equal PropertyStatuses::ARCHIVED, @property.status
    assert_nil @property.deleted_at, "archive must not soft-delete the property"

    # 7.8 sections and units are preserved
    assert PropertySection.exists?(@section.id)
    assert Unit.exists?(@unit.id)
    # 7.9 person relationships and staff assignments are preserved
    assert StaffAssignment.exists?(@staff_assignment.id)
    assert UnitOwnership.exists?(unit_id: @unit.id)
    # 7.10 visits are preserved
    assert Visit.exists?(@visit.id)
  end

  # 7.11 / §3.7 ---------------------------------------------------------------
  test "7.11 archive is idempotent for an already-archived property" do
    Properties::Archive.call(actor: @tenant_admin, property: @property)

    result = Properties::Archive.call(actor: @tenant_admin, property: @property)
    assert result.success?
    assert result.noop?
    assert_equal PropertyStatuses::ARCHIVED, @property.reload.status
  end
end
