# frozen_string_literal: true

require "test_helper"

class Units::ServicesTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "unit-svc-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @client = create_user_for_organization(
      organization: @organization,
      email: "unit-svc-client@example.test",
      role: AvailableRoles::CLIENT
    )
    @property = create_property(@organization, "Unit Service Property")
    @floor = PropertySection.create!(
      organization: @organization,
      residential_property: @property,
      name: "Piso 1",
      section_type: SectionTypes::FLOOR
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "normalize identifier trims and hyphenates without database access" do
    result = Units::NormalizeIdentifier.call("  Torre A 101 ")

    assert_equal "Torre A 101", result.identifier
    assert_equal "torre-a-101", result.normalized_identifier
    assert_nil Units::NormalizeIdentifier.call("")
  end

  test "create derives organization from property and defaults status to available" do
    result = Units::Create.call(
      actor: @tenant_admin,
      property: @property,
      attributes: { identifier: "A-101", unit_type: UnitTypes::APARTMENT }
    )

    assert result.success?
    assert_equal UnitStatuses::AVAILABLE, result.unit.status
    assert_equal @organization.id, result.unit.organization_id
    assert_equal @property.id, result.unit.residential_property_id
    assert_nil result.unit.property_section_id
  end

  test "create with section resolves section within property" do
    result = Units::Create.call(
      actor: @tenant_admin,
      property: @property,
      section_id: @floor.id,
      attributes: { identifier: "B-202", unit_type: UnitTypes::APARTMENT }
    )

    assert result.success?
    assert_equal @floor.id, result.unit.property_section_id
  end

  test "create ignores client-supplied organization property and normalized identifier" do
    result = Units::Create.call(
      actor: @tenant_admin,
      property: @property,
      attributes: {
        identifier: "C-303",
        unit_type: UnitTypes::APARTMENT,
        organization_id: @other_organization.id,
        residential_property_id: SecureRandom.uuid,
        normalized_identifier: "forged"
      }
    )

    assert result.success?
    assert_equal @organization.id, result.unit.organization_id
    assert_equal @property.id, result.unit.residential_property_id
    assert_equal "c-303", result.unit.normalized_identifier
  end

  test "create allows initial status override only when explicitly authorized" do
    default_result = Units::Create.call(
      actor: @tenant_admin,
      property: @property,
      attributes: { identifier: "D-404", unit_type: UnitTypes::APARTMENT, status: UnitStatuses::MAINTENANCE }
    )
    assert_equal UnitStatuses::AVAILABLE, default_result.unit.status

    import_result = Units::Create.call(
      actor: @tenant_admin,
      property: @property,
      allow_initial_status: true,
      attributes: { identifier: "E-505", unit_type: UnitTypes::APARTMENT, status: UnitStatuses::MAINTENANCE }
    )
    assert_equal UnitStatuses::MAINTENANCE, import_result.unit.status
  end

  test "create rejects mutation when property is archived" do
    @property.update!(status: PropertyStatuses::ARCHIVED)

    result = Units::Create.call(
      actor: @tenant_admin,
      property: @property,
      attributes: { identifier: "F-606", unit_type: UnitTypes::APARTMENT }
    )

    assert result.invalid?
    assert result.errors.of_kind?(:base, :property_not_operative)
  end

  test "update applies descriptive changes and operational status transitions" do
    unit = create_unit(@property, "UPD-1")

    result = Units::Update.call(
      actor: @tenant_admin,
      unit: unit,
      attributes: { display_name: "Renamed", status: UnitStatuses::MAINTENANCE }
    )

    assert result.success?
    unit.reload
    assert_equal "Renamed", unit.display_name
    assert_equal UnitStatuses::MAINTENANCE, unit.status
  end

  test "update rejects archive property and section changes" do
    unit = create_unit(@property, "UPD-2")
    other_property = create_property(@organization, "Other Property")

    archive_result = Units::Update.call(
      actor: @tenant_admin,
      unit: unit,
      attributes: { status: UnitStatuses::ARCHIVED }
    )
    assert archive_result.invalid?
    assert archive_result.errors.of_kind?(:status, :archive_requires_service)

    section_result = Units::Update.call(
      actor: @tenant_admin,
      unit: unit,
      attributes: { property_section_id: @floor.id }
    )
    assert section_result.success?
    assert_nil unit.reload.property_section_id

    property_result = Units::Update.call(
      actor: @tenant_admin,
      unit: unit,
      attributes: { residential_property_id: other_property.id }
    )
    assert property_result.success?
    assert_equal @property.id, unit.reload.residential_property_id
  end

  test "update regenerates derived code when identifier changes" do
    unit = create_unit(@property, "UPD-CODE-1")
    unit.update!(property_section: @floor)

    result = Units::Update.call(
      actor: @tenant_admin,
      unit: unit,
      attributes: { identifier: "UPD-CODE-2" }
    )

    assert result.success?
    unit.reload
    assert_equal "upd-code-2", unit.code
  end

  test "update rejects identifier change when regenerated code collides" do
    unit = create_unit(@property, "UPD-COL-1")
    unit.update!(property_section: @floor)
    # Simulates legacy data / a console correction: another unit in the same
    # section carries a code that does not match its own identifier, so the
    # collision is on `code` alone, not on `identifier` uniqueness.
    other = create_unit(@property, "UPD-COL-OTHER")
    other.update!(property_section: @floor)
    other.update_column(:code, "upd-col-2")

    result = Units::Update.call(
      actor: @tenant_admin,
      unit: unit,
      attributes: { identifier: "UPD-COL-2" }
    )

    assert result.invalid?
    assert_includes result.errors[:identifier], I18n.t("frontend.admin.units.validations.code_conflict")
    unit.reload
    assert_equal "UPD-COL-1", unit.identifier
  end

  test "move changes section within the same property and supports no-section context" do
    unit = create_unit(@property, "MOV-1")
    unit.update!(property_section: @floor)

    result = Units::MoveToSection.call(
      actor: @tenant_admin,
      unit: unit,
      section_id: nil
    )

    assert result.success?
    assert_nil unit.reload.property_section_id

    back = Units::MoveToSection.call(
      actor: @tenant_admin,
      unit: unit,
      section_id: @floor.id
    )
    assert back.success?
    assert_equal @floor.id, unit.reload.property_section_id
  end

  test "move is noop when section is unchanged" do
    unit = create_unit(@property, "MOV-2")
    unit.update!(property_section: @floor)

    result = Units::MoveToSection.call(
      actor: @tenant_admin,
      unit: unit,
      section_id: @floor.id
    )

    assert result.noop?
  end

  test "archive is non-destructive and idempotent" do
    unit = create_unit(@property, "ARC-1")
    ownership = UnitOwnership.create!(
      organization: @organization,
      person: @tenant_admin.person_for(@organization),
      unit: unit,
      ownership_percentage: 100,
      starts_at: Date.current,
      status: UnitOwnership::STATUS_ACTIVE
    )

    result = Units::Archive.call(actor: @tenant_admin, unit: unit)

    assert result.success?
    assert_equal UnitStatuses::ARCHIVED, unit.reload.status
    assert_nil unit.deleted_at
    assert UnitOwnership.exists?(ownership.id)

    noop = Units::Archive.call(actor: @tenant_admin, unit: unit)
    assert noop.noop?
  end

  test "restore revalidates uniqueness and preserves status" do
    unit = create_unit(@property, "RST-1")
    unit.update!(status: UnitStatuses::MAINTENANCE)
    Units::SoftDelete.call(actor: @tenant_admin, unit: unit)

    create_unit(@property, "RST-1")

    deleted = ::Unit.with_deleted.find(unit.id)
    result = Units::Restore.call(actor: @tenant_admin, unit: deleted)

    assert result.invalid?
    assert result.errors[:identifier].present?
    assert deleted.reload.deleted?

    ::Unit.where(identifier: "RST-1", residential_property: @property).find_each do |u|
      soft_delete_unit(u)
    end
    result = Units::Restore.call(actor: @tenant_admin, unit: deleted.reload)

    assert result.success?
    assert_nil deleted.reload.deleted_at
    assert_equal UnitStatuses::MAINTENANCE, deleted.status
  end

  test "denies unauthorized actors" do
    assert_raises(Pundit::NotAuthorizedError) do
      Units::Create.call(
        actor: @client,
        property: @property,
        attributes: { identifier: "FORBIDDEN", unit_type: UnitTypes::APARTMENT }
      )
    end
  end
end
