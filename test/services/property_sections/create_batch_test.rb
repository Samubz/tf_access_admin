# frozen_string_literal: true

require "test_helper"

# Per-parent heterogeneous batch creation reusing PropertySections::Create
# (wizard-manual-structure-builder). Each node still passes every hierarchy rule.
class PropertySections::CreateBatchTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @actor = create_user_for_organization(
      organization: @organization,
      email: "create-batch-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @property = create_property(@organization, "Create Batch Property")
    @tower = root_section(@property, "Torre A")
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "creates multiple root sections with a letter format" do
    result = PropertySections::CreateBatch.call(
      actor: @actor, property: @property, section_type: SectionTypes::TOWER,
      prefix: "Edificio", suffix_type: :letter, count: 3
    )

    assert result.success?
    assert_equal 3, result.sections.size
    assert_equal [ "Edificio A", "Edificio B", "Edificio C" ], result.sections.map(&:name)
    assert(result.sections.all?(&:root_section?))
  end

  test "creates multiple child sections with a numeric format under a root" do
    result = PropertySections::CreateBatch.call(
      actor: @actor, property: @property, parent: @tower,
      section_type: SectionTypes::FLOOR, prefix: "Piso", suffix_type: :number, count: 2
    )

    assert result.success?
    assert_equal [ "Piso 1", "Piso 2" ], result.sections.map(&:name)
    assert(result.sections.all? { |section| section.parent_id == @tower.id })
  end

  test "individual mode creates exactly one section from an explicit name" do
    result = PropertySections::CreateBatch.call(
      actor: @actor, property: @property, section_type: SectionTypes::TOWER,
      names: [ "Lobby" ]
    )

    assert result.success?
    assert_equal 1, result.sections.size
    assert_equal "Lobby", result.sections.first.name
  end

  test "rejects a child batch under a non-root parent and rolls back" do
    floor = @property.property_sections.create!(
      organization: @organization, name: "Piso 1",
      section_type: SectionTypes::FLOOR, parent: @tower
    )

    assert_no_difference -> { @property.property_sections.count } do
      result = PropertySections::CreateBatch.call(
        actor: @actor, property: @property, parent: floor,
        section_type: SectionTypes::BLOCK, prefix: "Ala", suffix_type: :letter, count: 2
      )

      assert result.invalid?
      assert_includes result.section.errors[:parent_id],
                      I18n.t("frontend.admin.property_sections.validations.parent_must_be_root")
    end
  end

  test "skips taken names and creates the next available siblings" do
    root_section(@property, "Edificio B")

    assert_difference -> { @property.property_sections.count }, 2 do
      result = PropertySections::CreateBatch.call(
        actor: @actor, property: @property, section_type: SectionTypes::TOWER,
        prefix: "Edificio", suffix_type: :letter, count: 2
      )

      assert result.success?
      assert_equal [ "Edificio A", "Edificio C" ], result.sections.map(&:name)
    end
  end

  test "creates numeric names alongside a non-sequential sibling name" do
    root_section(@property, "Torre 123")

    result = PropertySections::CreateBatch.call(
      actor: @actor, property: @property, section_type: SectionTypes::TOWER,
      prefix: "Torre", suffix_type: :number, count: 2
    )

    assert result.success?
    assert_equal [ "Torre 1", "Torre 2" ], result.sections.map(&:name)
  end

  test "returns insufficient_available_names when not enough suffixes remain" do
    # @tower already occupies "Torre A"; fill "Torre B".."Torre Z" so the whole
    # letter range (A–Z) is taken.
    ("B".."Z").each { |letter| root_section(@property, "Torre #{letter}") }

    result = PropertySections::CreateBatch.call(
      actor: @actor, property: @property, section_type: SectionTypes::TOWER,
      prefix: "Torre", suffix_type: :letter, count: 1
    )

    assert result.invalid?
    assert result.section.errors.of_kind?(:base, :insufficient_available_names)
  end

  test "empty batch is invalid" do
    result = PropertySections::CreateBatch.call(
      actor: @actor, property: @property, section_type: SectionTypes::TOWER,
      prefix: "Torre", suffix_type: :letter, count: 0
    )

    assert result.invalid?
  end

  private

  def root_section(property, name)
    property.property_sections.create!(
      organization: property.organization, name: name, section_type: SectionTypes::TOWER
    )
  end
end
