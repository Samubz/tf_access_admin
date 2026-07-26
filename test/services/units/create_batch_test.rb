# frozen_string_literal: true

require "test_helper"

# Manual multiple unit creation reusing Units::Create per generated identifier
# (add-manual-section-units). Each unit still passes every Unit validation and
# code derivation rule; the whole batch is all-or-nothing.
class Units::CreateBatchTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @actor = create_user_for_organization(
      organization: @organization,
      email: "unit-batch-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @client = create_user_for_organization(
      organization: @organization,
      email: "unit-batch-client@example.test",
      role: AvailableRoles::CLIENT
    )

    @property = create_property(@organization, "Unit Batch Property")
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

  test "creates multiple units in an eligible section with a letter format" do
    result = Units::CreateBatch.call(
      actor: @actor, property: @property, section_id: @floor.id,
      attributes: { unit_type: UnitTypes::APARTMENT },
      prefix: "Depto", suffix_type: :letter, count: 3
    )

    assert result.success?
    assert_equal 3, result.units.size
    assert_equal [ "Depto A", "Depto B", "Depto C" ], result.units.map(&:identifier)
    assert(result.units.all? { |unit| unit.property_section_id == @floor.id })
  end

  test "skips taken identifiers and creates the next available siblings" do
    Units::Create.call(
      actor: @actor, property: @property, section_id: @floor.id,
      attributes: { identifier: "Depto B", unit_type: UnitTypes::APARTMENT }
    )

    assert_difference -> { @property.units.count }, 2 do
      result = Units::CreateBatch.call(
        actor: @actor, property: @property, section_id: @floor.id,
        attributes: { unit_type: UnitTypes::APARTMENT },
        prefix: "Depto", suffix_type: :letter, count: 2
      )

      assert result.success?
      assert_equal [ "Depto A", "Depto C" ], result.units.map(&:identifier)
    end
  end

  test "is rejected without an eligible section" do
    result = Units::CreateBatch.call(
      actor: @actor, property: @property, section_id: nil,
      attributes: { unit_type: UnitTypes::APARTMENT },
      prefix: "Depto", suffix_type: :letter, count: 2
    )

    assert result.invalid?
    assert result.unit.errors[:property_section_id].present?
    assert_equal 0, @property.units.count
  end

  test "rejects a section that cannot contain units and rolls back" do
    non_leaf = @property.property_sections.create!(
      organization: @organization, name: "Torre Padre", section_type: SectionTypes::TOWER
    )
    @property.property_sections.create!(
      organization: @organization, name: "Piso hijo", section_type: SectionTypes::FLOOR, parent: non_leaf
    )

    result = Units::CreateBatch.call(
      actor: @actor, property: @property, section_id: non_leaf.id,
      attributes: { unit_type: UnitTypes::APARTMENT },
      prefix: "Depto", suffix_type: :letter, count: 2
    )

    assert result.invalid?
    assert_equal 0, @property.units.count
  end

  test "returns insufficient identifiers when not enough suffixes remain and creates nothing" do
    ("B".."Z").each do |letter|
      Units::Create.call(
        actor: @actor, property: @property, section_id: @floor.id,
        attributes: { identifier: "Depto #{letter}", unit_type: UnitTypes::APARTMENT }
      )
    end

    result = Units::CreateBatch.call(
      actor: @actor, property: @property, section_id: @floor.id,
      attributes: { unit_type: UnitTypes::APARTMENT },
      prefix: "Depto", suffix_type: :letter, count: 2
    )

    assert result.invalid?
    assert result.unit.errors.of_kind?(:base, :insufficient_available_identifiers)
    assert_equal 25, @property.units.count
  end

  test "rolls back the whole batch when a generated unit fails validation" do
    assert_no_difference -> { @property.units.count } do
      result = Units::CreateBatch.call(
        actor: @actor, property: @property, section_id: @floor.id,
        attributes: { unit_type: "not-a-real-type" },
        prefix: "Depto", suffix_type: :letter, count: 3
      )

      assert result.invalid?
    end
  end

  test "denies unauthorized actors" do
    assert_raises(Pundit::NotAuthorizedError) do
      Units::CreateBatch.call(
        actor: @client, property: @property, section_id: @floor.id,
        attributes: { unit_type: UnitTypes::APARTMENT },
        prefix: "Depto", suffix_type: :letter, count: 2
      )
    end
  end
end
