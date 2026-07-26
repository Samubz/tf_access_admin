# frozen_string_literal: true

require "test_helper"

# PropertySections domain services (improve-property-sections §4).
class PropertySections::ServicesTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "section-svc-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @client = create_user_for_organization(
      organization: @organization,
      email: "section-svc-client@example.test",
      role: AvailableRoles::CLIENT
    )
    @property = create_property(@organization, "Section Service Property")
    @tower = PropertySection.create!(
      organization: @organization,
      residential_property: @property,
      name: "Torre A",
      section_type: SectionTypes::TOWER
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "create derives organization from property and defaults status to active" do
    result = PropertySections::Create.call(
      actor: @tenant_admin,
      property: @property,
      attributes: { name: "Torre B", section_type: SectionTypes::TOWER }
    )

    assert result.success?
    assert_equal SectionStatuses::ACTIVE, result.section.status
    assert_equal @organization.id, result.section.organization_id
    assert_equal @property.id, result.section.residential_property_id
  end

  test "create ignores a client-supplied organization_id" do
    result = PropertySections::Create.call(
      actor: @tenant_admin,
      property: @property,
      attributes: {
        name: "Torre C",
        section_type: SectionTypes::TOWER,
        organization_id: @other_organization.id
      }
    )

    assert result.success?
    assert_equal @organization.id, result.section.organization_id
  end

  test "create rejects mutation when property is archived" do
    @property.update!(status: PropertyStatuses::ARCHIVED)

    result = PropertySections::Create.call(
      actor: @tenant_admin,
      property: @property,
      attributes: { name: "Blocked", section_type: SectionTypes::TOWER }
    )

    assert result.invalid?
    assert result.errors.of_kind?(:base, :property_not_operative)
  end

  test "update applies descriptive changes and active/inactive transitions" do
    result = PropertySections::Update.call(
      actor: @tenant_admin,
      section: @tower,
      attributes: { name: "Torre Renamed", status: SectionStatuses::INACTIVE }
    )

    assert result.success?
    assert_equal "Torre Renamed", @tower.reload.name
    assert_equal SectionStatuses::INACTIVE, @tower.status
  end

  test "update rejects archive and parent changes" do
    archive_result = PropertySections::Update.call(
      actor: @tenant_admin,
      section: @tower,
      attributes: { status: SectionStatuses::ARCHIVED }
    )
    assert archive_result.invalid?
    assert archive_result.errors.of_kind?(:status, :archive_requires_service)

    move_result = PropertySections::Update.call(
      actor: @tenant_admin,
      section: @tower,
      attributes: { parent_id: SecureRandom.uuid }
    )
    assert move_result.invalid?
    assert move_result.errors.of_kind?(:parent_id, :move_requires_service)
  end

  test "move changes parent within the same property" do
    tower_b = PropertySection.create!(
      organization: @organization,
      residential_property: @property,
      name: "Torre B",
      section_type: SectionTypes::TOWER
    )
    floor = PropertySection.create!(
      organization: @organization,
      residential_property: @property,
      name: "Piso 1",
      section_type: SectionTypes::FLOOR,
      parent: @tower
    )

    result = PropertySections::Move.call(
      actor: @tenant_admin,
      section: floor,
      parent_id: tower_b.id
    )

    assert result.success?
    assert_equal tower_b.id, floor.reload.parent_id
    assert_equal @property.id, floor.residential_property_id
  end

  test "archive is non-destructive and idempotent" do
    child = PropertySection.create!(
      organization: @organization,
      residential_property: @property,
      name: "Piso 1",
      section_type: SectionTypes::FLOOR,
      parent: @tower
    )
    unit = create_unit(@property, "SEC-101")
    unit.update!(property_section: child)

    result = PropertySections::Archive.call(actor: @tenant_admin, section: @tower)

    assert result.success?
    assert_equal SectionStatuses::ARCHIVED, @tower.reload.status
    assert PropertySection.exists?(child.id)
    assert Unit.exists?(unit.id)
    assert_nil @tower.deleted_at

    noop = PropertySections::Archive.call(actor: @tenant_admin, section: @tower)
    assert noop.noop?
  end

  test "denies unauthorized actors" do
    assert_raises(Pundit::NotAuthorizedError) do
      PropertySections::Create.call(
        actor: @client,
        property: @property,
        attributes: { name: "Forbidden", section_type: SectionTypes::TOWER }
      )
    end
  end
end
