# frozen_string_literal: true

require "test_helper"

# Move/archive hierarchy guarantees and concurrent-conflict translation for the
# section services (improve-property-sections §9.11-9.14, §9.23).
class PropertySections::MoveAndConflictsTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @actor = create_user_for_organization(
      organization: @organization,
      email: "move-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @property = create_property(@organization, "Move Property")
    @tower_a = section("Torre A", SectionTypes::TOWER)
    @tower_b = section("Torre B", SectionTypes::TOWER)
    @floor = section("Piso 1", SectionTypes::FLOOR, parent: @tower_a)
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  # 9.11
  test "moves a subsection to another root and back to the root context" do
    to_b = PropertySections::Move.call(actor: @actor, section: @floor, parent_id: @tower_b.id)
    assert to_b.success?
    assert_equal @tower_b.id, @floor.reload.parent_id

    to_root = PropertySections::Move.call(actor: @actor, section: @floor, parent_id: nil)
    assert to_root.success?
    assert_nil @floor.reload.parent_id
  end

  # 9.11 (subtree preserved, still two levels)
  test "moving a root under another root preserves its subtree" do
    result = PropertySections::Move.call(actor: @actor, section: @tower_a, parent_id: @tower_b.id)

    # tower_a has a child, so nesting it would create a third level: rejected.
    assert result.invalid?
    assert_not_empty result.errors[:parent_id]
    assert_nil @tower_a.reload.parent_id
    assert_equal @tower_a.id, @floor.reload.parent_id
  end

  # 9.12
  test "rejects a move that would create a third level" do
    sub = section("Sub", SectionTypes::BLOCK, parent: @tower_b)

    result = PropertySections::Move.call(actor: @actor, section: sub, parent_id: @floor.id)

    assert result.invalid?
    assert_includes result.errors[:parent_id],
                    I18n.t("frontend.admin.property_sections.validations.parent_must_be_root")
  end

  # 9.13
  test "rejects a move onto a descendant" do
    result = PropertySections::Move.call(actor: @actor, section: @tower_a, parent_id: @floor.id)

    assert result.invalid?
    assert_not_empty result.errors[:parent_id]
  end

  # 9.13
  test "rejects a cross-property move" do
    other_property = create_property(@organization, "Move Target Property")
    other_root = other_property.property_sections.create!(
      organization: @organization,
      name: "Torre Externa",
      section_type: SectionTypes::TOWER
    )

    result = PropertySections::Move.call(actor: @actor, section: @floor, parent_id: other_root.id)

    assert result.invalid?
    assert_includes result.errors[:parent_id],
                    I18n.t("frontend.admin.property_sections.validations.parent_same_property")
    assert_equal @tower_a.id, @floor.reload.parent_id
  end

  # 9.14
  test "archive keeps the subtree and units without a hard delete" do
    unit = create_unit(@property, "MOVE-101")
    unit.update!(property_section: @floor)

    result = PropertySections::Archive.call(actor: @actor, section: @tower_a)

    assert result.success?
    assert_equal SectionStatuses::ARCHIVED, @tower_a.reload.status
    assert PropertySection.exists?(@floor.id)
    assert Unit.exists?(unit.id)
    assert_nil @tower_a.deleted_at
    assert_nil @floor.reload.deleted_at
  end

  # 9.23
  test "a duplicate sibling name becomes a structured domain error" do
    result = PropertySections::Create.call(
      actor: @actor,
      property: @property,
      attributes: { name: "Torre A", section_type: SectionTypes::TOWER }
    )

    assert result.invalid?
    assert result.errors.of_kind?(:name, :taken)
  end

  # 9.23
  test "a concurrent unique violation is translated into a field error" do
    section = @property.property_sections.new(
      organization: @organization,
      name: "Concurrent",
      section_type: SectionTypes::TOWER
    )
    exception = ActiveRecord::RecordNotUnique.new(
      "PG::UniqueViolation: idx_property_sections_unique_root_name"
    )

    section.register_uniqueness_conflict(exception)

    assert section.errors.of_kind?(:name, :taken)
  end

  private

  def section(name, type, parent: nil)
    @property.property_sections.create!(
      organization: @organization,
      name: name,
      section_type: type,
      parent: parent
    )
  end
end
