# frozen_string_literal: true

require "test_helper"

# Parent resolution for PropertySections::Create (improve-property-sections §3):
# a requested-but-invalid parent must fail loudly and never collapse silently
# into a root section.
class PropertySections::CreateParentTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @actor = create_user_for_organization(
      organization: @organization,
      email: "create-parent-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @property = create_property(@organization, "Create Parent Property")
    @tower = root_section(@property, "Torre A")
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "creates a root section when parent_id is omitted" do
    result = create(name: "Torre B")

    assert result.success?
    assert_nil result.section.parent_id
    assert_predicate result.section, :root_section?
  end

  test "creates a root section when parent_id is blank" do
    result = create(name: "Torre C", parent_id: "")

    assert result.success?
    assert_nil result.section.parent_id
  end

  test "creates a subsection with a valid parent_id" do
    result = create(name: "Piso 1", section_type: SectionTypes::FLOOR, parent_id: @tower.id)

    assert result.success?
    assert_equal @tower.id, result.section.parent_id
  end

  test "rejects a non-existent parent_id without creating a root" do
    assert_no_difference -> { @property.property_sections.count } do
      result = create(name: "Orphan", parent_id: SecureRandom.uuid)

      assert result.invalid?
      assert result.errors.of_kind?(:parent_id, :parent_invalid)
      assert_not result.section.persisted?
    end
  end

  test "rejects a parent from another property without creating a root" do
    other_property = create_property(@organization, "Other Create Property")
    foreign_parent = root_section(other_property, "Torre Externa")

    assert_no_difference -> { @property.property_sections.count } do
      result = create(name: "Cross Prop", parent_id: foreign_parent.id)

      assert result.invalid?
      assert result.errors.of_kind?(:parent_id, :parent_invalid)
    end
  end

  test "rejects a parent from another organization without creating a root" do
    foreign_parent = nil
    ActsAsTenant.with_tenant(@other_organization) do
      foreign_property = create_property(@other_organization, "Foreign Create Property")
      foreign_parent = root_section(foreign_property, "Torre Foránea")
    end

    assert_no_difference -> { @property.property_sections.count } do
      result = create(name: "Cross Org", parent_id: foreign_parent.id)

      assert result.invalid?
      assert result.errors.of_kind?(:parent_id, :parent_invalid)
    end
  end

  test "rejects a parent that is already a subsection (two-level limit)" do
    floor = @property.property_sections.create!(
      organization: @organization,
      name: "Piso 1",
      section_type: SectionTypes::FLOOR,
      parent: @tower
    )

    result = create(name: "Ala B", section_type: SectionTypes::BLOCK, parent_id: floor.id)

    assert result.invalid?
    assert_includes result.section.errors[:parent_id],
                    I18n.t("frontend.admin.property_sections.validations.parent_must_be_root")
  end

  test "rejects an inactive or archived parent" do
    @tower.update!(status: SectionStatuses::ARCHIVED)

    result = create(name: "Piso bajo archivado", section_type: SectionTypes::FLOOR, parent_id: @tower.id)

    assert result.invalid?
    assert_includes result.section.errors[:parent_id],
                    I18n.t("frontend.admin.property_sections.validations.parent_not_operative")
  end

  private

  def create(name:, section_type: SectionTypes::TOWER, **attributes)
    PropertySections::Create.call(
      actor: @actor,
      property: @property,
      attributes: { name: name, section_type: section_type, **attributes }
    )
  end

  def root_section(property, name)
    property.property_sections.create!(
      organization: property.organization,
      name: name,
      section_type: SectionTypes::TOWER
    )
  end
end
