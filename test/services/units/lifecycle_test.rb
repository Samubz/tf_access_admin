# frozen_string_literal: true

require "test_helper"

class Units::LifecycleTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "unit-lifecycle-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @property = create_property(@organization, "Unit Lifecycle Property")
    @person = Person.create!(
      organization: @organization,
      display_name: "Lifecycle Test Person",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @host_person = Person.create!(
      organization: @organization,
      display_name: "Lifecycle Test Host",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "archive sets status archived without soft delete" do
    unit = create_unit(@property, "ARC-LC-1")

    result = Units::Archive.call(actor: @tenant_admin, unit: unit)

    assert result.success?
    unit.reload
    assert_equal UnitStatuses::ARCHIVED, unit.status
    assert_nil unit.deleted_at
  end

  test "archived unit keeps identifier reserved" do
    unit = create_unit(@property, "ARC-LC-2")
    Units::Archive.call(actor: @tenant_admin, unit: unit)

    duplicate = Units::Create.call(
      actor: @tenant_admin,
      property: @property,
      attributes: { identifier: "ARC-LC-2", unit_type: UnitTypes::APARTMENT }
    )

    assert duplicate.invalid?
    assert duplicate.errors[:identifier].present?
  end

  test "direct destroy is blocked outside the soft delete service" do
    unit = create_unit(@property, "SD-LC-1")

    assert_not unit.destroy
    assert unit.persisted?
    assert_nil unit.deleted_at
    assert unit.errors.of_kind?(:base, :destroy_requires_service)
  end

  test "soft delete releases uniqueness context" do
    unit = create_unit(@property, "SD-LC-2")

    result = Units::SoftDelete.call(actor: @tenant_admin, unit: unit)

    assert result.success?
    assert_not_nil unit.reload.deleted_at
    assert_equal UnitStatuses::AVAILABLE, unit.status

    replacement = Units::Create.call(
      actor: @tenant_admin,
      property: @property,
      attributes: { identifier: "SD-LC-2", unit_type: UnitTypes::APARTMENT }
    )

    assert replacement.success?
  end

  test "restore rejects reused context and preserves archived status" do
    unit = create_unit(@property, "RST-LC-1")
    Units::Archive.call(actor: @tenant_admin, unit: unit)
    Units::SoftDelete.call(actor: @tenant_admin, unit: unit)

    create_unit(@property, "RST-LC-1")

    deleted = ::Unit.with_deleted.find(unit.id)
    conflict = Units::Restore.call(actor: @tenant_admin, unit: deleted)

    assert conflict.invalid?
    assert conflict.errors[:identifier].present?
    assert deleted.reload.deleted?

    ::Unit.where(identifier: "RST-LC-1", residential_property: @property).find_each do |u|
      soft_delete_unit(u)
    end
    success = Units::Restore.call(actor: @tenant_admin, unit: deleted.reload)

    assert success.success?
    assert_nil deleted.reload.deleted_at
    assert_equal UnitStatuses::ARCHIVED, deleted.status
  end

  test "reactivate transitions archived unit to operational status" do
    unit = create_unit(@property, "REA-LC-1")
    Units::Archive.call(actor: @tenant_admin, unit: unit)

    result = Units::Reactivate.call(
      actor: @tenant_admin,
      unit: unit,
      status: UnitStatuses::AVAILABLE
    )

    assert result.success?
    assert_equal UnitStatuses::AVAILABLE, unit.reload.status
    assert_nil unit.deleted_at
  end

  test "reactivate rejects non-archived units" do
    unit = create_unit(@property, "REA-LC-2")

    result = Units::Reactivate.call(actor: @tenant_admin, unit: unit)

    assert result.invalid?
    assert result.errors.of_kind?(:status, :reactivate_requires_archived)
  end

  # Soft delete preserves relationships (§3.4)
  test "soft delete preserves unit ownerships" do
    unit = create_unit(@property, "SD-OWN-1")
    ownership = unit.unit_ownerships.create!(
      person: @person,
      ownership_percentage: 50.0,
      starts_at: 1.day.ago
    )

    Units::SoftDelete.call(actor: @tenant_admin, unit: unit)

    assert unit.reload.deleted?
    ownership.reload
    assert ownership.unit_id == unit.id
    assert_nil ownership.deleted_at
  end

  test "soft delete preserves unit occupancies" do
    unit = create_unit(@property, "SD-OCC-1")
    occupancy = unit.unit_occupancies.create!(
      person: @person,
      occupancy_type: OccupancyTypes::TENANT,
      status: OccupancyStatuses::ACTIVE,
      starts_at: 1.day.ago
    )

    Units::SoftDelete.call(actor: @tenant_admin, unit: unit)

    assert unit.reload.deleted?
    occupancy.reload
    assert occupancy.unit_id == unit.id
    assert_nil occupancy.deleted_at
  end

  test "soft delete preserves lease contracts" do
    unit = create_unit(@property, "SD-LEASE-1")
    lease = unit.lease_contracts.create!(
      lessee_person: @person,
      status: "active",
      starts_at: 1.day.ago
    )

    Units::SoftDelete.call(actor: @tenant_admin, unit: unit)

    assert unit.reload.deleted?
    lease.reload
    assert lease.unit_id == unit.id
  end

  test "soft delete preserves authorized residents" do
    unit = create_unit(@property, "SD-AUTH-1")
    authorized = unit.authorized_residents.create!(
      person: @person,
      relationship_type: RelationshipTypes::SPOUSE,
      starts_at: 1.day.ago
    )

    Units::SoftDelete.call(actor: @tenant_admin, unit: unit)

    assert unit.reload.deleted?
    authorized.reload
    assert authorized.unit_id == unit.id
  end

  test "soft delete preserves visits" do
    unit = create_unit(@property, "SD-VISIT-1")

    visit = unit.visits.create!(
      residential_property: @property,
      visitor_person: @person,
      visit_type: VisitTypes::GUEST,
      status: VisitStatuses::AUTHORIZED,
      scheduled_at: 1.day.from_now,
      valid_from: Time.current
    )

    Units::SoftDelete.call(actor: @tenant_admin, unit: unit)

    assert unit.reload.deleted?
    visit.reload
    assert visit.unit_id == unit.id
  end

  # Archive preserves relationships (§3.3)
  test "archive preserves unit ownerships" do
    unit = create_unit(@property, "ARC-OWN-1")
    ownership = unit.unit_ownerships.create!(
      person: @person,
      ownership_percentage: 50.0,
      starts_at: 1.day.ago
    )

    Units::Archive.call(actor: @tenant_admin, unit: unit)

    unit.reload
    assert_equal UnitStatuses::ARCHIVED, unit.status
    assert_nil unit.deleted_at
    ownership.reload
    assert ownership.unit_id == unit.id
    assert_nil ownership.deleted_at
  end

  test "archive preserves unit occupancies" do
    unit = create_unit(@property, "ARC-OCC-1")
    occupancy = unit.unit_occupancies.create!(
      person: @person,
      occupancy_type: OccupancyTypes::TENANT,
      status: OccupancyStatuses::ACTIVE,
      starts_at: 1.day.ago
    )

    Units::Archive.call(actor: @tenant_admin, unit: unit)

    unit.reload
    assert_equal UnitStatuses::ARCHIVED, unit.status
    occupancy.reload
    assert occupancy.unit_id == unit.id
    assert_nil occupancy.deleted_at
  end

  # Restore preserves relationships (§3.4)
  test "restore preserves relationships after soft delete" do
    unit = create_unit(@property, "RST-REL-1")
    ownership = unit.unit_ownerships.create!(
      person: @person,
      ownership_percentage: 50.0,
      starts_at: 1.day.ago
    )
    occupancy = unit.unit_occupancies.create!(
      person: @person,
      occupancy_type: OccupancyTypes::TENANT,
      status: OccupancyStatuses::ACTIVE,
      starts_at: 1.day.ago
    )

    Units::SoftDelete.call(actor: @tenant_admin, unit: unit)

    deleted = ::Unit.with_deleted.find(unit.id)
    Units::Restore.call(actor: @tenant_admin, unit: deleted)

    unit.reload
    assert_not_nil unit
    assert_nil unit.deleted_at
    ownership.reload
    assert_nil ownership.deleted_at
    occupancy.reload
    assert_nil occupancy.deleted_at
  end

  # Restore property and section validation (§3.5/§3.6)
  test "restore rejects archived property" do
    unit = create_unit(@property, "RST-PROP-ARC")
    Units::SoftDelete.call(actor: @tenant_admin, unit: unit)

    @property.update!(status: PropertyStatuses::ARCHIVED)
    deleted = ::Unit.with_deleted.find(unit.id)

    result = Units::Restore.call(actor: @tenant_admin, unit: deleted)

    assert result.invalid?
    assert result.errors.of_kind?(:base, :property_not_operative)
    assert deleted.reload.deleted?
  end

  test "restore with section validates property and section state" do
    section = @property.property_sections.create!(
      organization: @organization,
      name: "Test Section",
      section_type: SectionTypes::FLOOR
    )
    unit = create_unit(@property, "RST-WITH-SEC")
    unit.update!(property_section: section)
    Units::SoftDelete.call(actor: @tenant_admin, unit: unit)

    deleted = ::Unit.with_deleted.find(unit.id)
    result = Units::Restore.call(actor: @tenant_admin, unit: deleted)

    assert result.success?
    assert_nil deleted.reload.deleted_at
  end

  test "restore without section validates unit stays valid" do
    unit = create_unit(@property, "RST-NO-SEC")
    Units::SoftDelete.call(actor: @tenant_admin, unit: unit)

    @property.update!(status: PropertyStatuses::INACTIVE)
    deleted = ::Unit.with_deleted.find(unit.id)

    result = Units::Restore.call(actor: @tenant_admin, unit: deleted)

    assert result.invalid?
    assert result.errors.of_kind?(:base, :property_not_operative)
    assert deleted.reload.deleted?
  end

  test "restore maintains deleted_at on all validation failures" do
    unit = create_unit(@property, "RST-MAINT-DEL")
    original_deleted_at = Time.current
    Units::SoftDelete.call(actor: @tenant_admin, unit: unit)

    deleted = ::Unit.with_deleted.find(unit.id)
    saved_deleted_at = deleted.deleted_at

    @property.update!(status: PropertyStatuses::ARCHIVED)
    Units::Restore.call(actor: @tenant_admin, unit: deleted)

    deleted.reload
    assert deleted.deleted?
    assert_equal saved_deleted_at, deleted.deleted_at
  end
end
