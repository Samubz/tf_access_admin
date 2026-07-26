# frozen_string_literal: true

# == Schema Information
#
# Table name: property_sections
#
#  id                      :uuid             not null, primary key
#  code                    :string
#  deleted_at              :datetime
#  metadata                :jsonb            not null
#  name                    :string           not null
#  normalized_name         :string           not null
#  position                :integer
#  section_type            :string           not null
#  status                  :string           default("active"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  organization_id         :uuid             not null
#  parent_id               :uuid
#  residential_property_id :uuid             not null
#
# Indexes
#
#  idx_property_sections_on_org_property_parent        (organization_id,residential_property_id,parent_id)
#  idx_property_sections_property_parent_position      (residential_property_id,parent_id,position)
#  idx_property_sections_unique_child_name             (organization_id,residential_property_id,parent_id,normalized_name) UNIQUE WHERE ((parent_id IS NOT NULL) AND (deleted_at IS NULL))
#  idx_property_sections_unique_code_in_context        (organization_id,residential_property_id,parent_id,section_type,code) UNIQUE WHERE ((code IS NOT NULL) AND (deleted_at IS NULL))
#  idx_property_sections_unique_root_name              (organization_id,residential_property_id,normalized_name) UNIQUE WHERE ((parent_id IS NULL) AND (deleted_at IS NULL))
#  index_property_sections_on_deleted_at               (deleted_at)
#  index_property_sections_on_metadata                 (metadata) USING gin
#  index_property_sections_on_organization_id          (organization_id)
#  index_property_sections_on_parent_id                (parent_id)
#  index_property_sections_on_residential_property_id  (residential_property_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (parent_id => property_sections.id)
#  fk_rails_...  (residential_property_id => residential_properties.id)
#
require "test_helper"

# Model-level rules for PropertySection (improve-property-sections §9, model items
# 9.1-9.10, 9.15, 9.17). Hierarchy nesting cases also live in
# PropertySectionHierarchyTest; this file focuses on presence, normalization,
# uniqueness, type/status, ordering, effective status and unit eligibility.
class PropertySectionTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization

    @property = create_property(@organization, "Section Model Property")
    @tower = @property.property_sections.create!(
      organization: @organization,
      name: "Torre A",
      section_type: SectionTypes::TOWER
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  # 9.1
  test "creates a root section and a subsection" do
    floor = @property.property_sections.create!(
      organization: @organization,
      name: "Piso 1",
      section_type: SectionTypes::FLOOR,
      parent: @tower
    )

    assert_predicate @tower, :root_section?
    assert_predicate floor, :child_section?
    assert_equal @tower.id, floor.parent_id
  end

  # 9.2
  test "rejects creating a third level" do
    floor = @property.property_sections.create!(
      organization: @organization,
      name: "Piso 1",
      section_type: SectionTypes::FLOOR,
      parent: @tower
    )

    nested = @property.property_sections.build(
      organization: @organization,
      name: "Ala B",
      section_type: SectionTypes::BLOCK,
      parent: floor
    )

    assert_not nested.valid?
    assert_includes nested.errors[:parent_id],
                    I18n.t("frontend.admin.property_sections.validations.parent_must_be_root")
  end

  # 9.3
  test "requires organization and property" do
    section = PropertySection.new(name: "Orphan", section_type: SectionTypes::TOWER)

    assert_not section.valid?
    assert section.errors.of_kind?(:residential_property, :blank)
  end

  # 9.3
  test "organization must match the property organization" do
    other_property = nil
    ActsAsTenant.with_tenant(@other_organization) do
      other_property = create_property(@other_organization, "Other Org Property")
    end

    section = PropertySection.new(
      organization: @organization,
      residential_property: other_property,
      name: "Mismatch",
      section_type: SectionTypes::TOWER
    )

    assert_not section.valid?
    assert section.errors.of_kind?(:organization_id, :mismatch_property)
  end

  # 9.4
  test "rejects a parent from another property" do
    other_property = create_property(@organization, "Second Property")
    other_root = other_property.property_sections.create!(
      organization: @organization,
      name: "Torre X",
      section_type: SectionTypes::TOWER
    )

    section = @property.property_sections.build(
      organization: @organization,
      name: "Piso cross",
      section_type: SectionTypes::FLOOR,
      parent: other_root
    )

    assert_not section.valid?
    assert_includes section.errors[:parent_id],
                    I18n.t("frontend.admin.property_sections.validations.parent_same_property")
  end

  # 9.4
  test "rejects a parent from another organization" do
    other_root = nil
    ActsAsTenant.with_tenant(@other_organization) do
      other_property = create_property(@other_organization, "Cross Org Property")
      other_root = other_property.property_sections.create!(
        organization: @other_organization,
        name: "Torre Y",
        section_type: SectionTypes::TOWER
      )
    end

    section = @property.property_sections.build(
      organization: @organization,
      name: "Piso cross org",
      section_type: SectionTypes::FLOOR,
      parent_id: other_root.id
    )

    assert_not section.valid?
    assert_not_empty section.errors[:parent_id]
  end

  # 9.5
  test "rejects self as parent" do
    @tower.parent_id = @tower.id

    assert_not @tower.valid?
    assert_includes @tower.errors[:parent_id],
                    I18n.t("frontend.admin.property_sections.validations.parent_invalid")
  end

  # 9.5
  test "rejects an indirect cycle through a descendant" do
    floor = @property.property_sections.create!(
      organization: @organization,
      name: "Piso 1",
      section_type: SectionTypes::FLOOR,
      parent: @tower
    )

    @tower.parent = floor

    assert_not @tower.valid?
    assert_not_empty @tower.errors[:parent_id]
  end

  # 9.6
  test "normalizes name with trim, whitespace collapse and case folding" do
    section = @property.property_sections.create!(
      organization: @organization,
      name: "  Piso   Uno  ",
      section_type: SectionTypes::FLOOR
    )

    assert_equal "Piso Uno", section.name
    assert_equal "piso uno", section.normalized_name
  end

  # 9.6
  test "rejects a duplicate normalized name among siblings" do
    duplicate = @property.property_sections.build(
      organization: @organization,
      name: "torre a",
      section_type: SectionTypes::TOWER
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:name, :taken)
  end

  # 9.7
  test "allows the same name under a different parent" do
    @property.property_sections.create!(
      organization: @organization,
      name: "Piso 1",
      section_type: SectionTypes::FLOOR,
      parent: @tower
    )
    tower_b = @property.property_sections.create!(
      organization: @organization,
      name: "Torre B",
      section_type: SectionTypes::TOWER
    )

    twin = @property.property_sections.build(
      organization: @organization,
      name: "Piso 1",
      section_type: SectionTypes::FLOOR,
      parent: tower_b
    )

    assert_predicate twin, :valid?
  end

  # 9.8
  test "enforces uniqueness among root sections" do
    duplicate_root = @property.property_sections.build(
      organization: @organization,
      name: "Torre A",
      section_type: SectionTypes::TOWER
    )

    assert_not duplicate_root.valid?
    assert duplicate_root.errors.of_kind?(:name, :taken)
  end

  # 9.9
  test "validates section_type and status against the catalogs" do
    invalid_type = @property.property_sections.build(
      organization: @organization,
      name: "Bad type",
      section_type: "spaceship"
    )
    assert_not invalid_type.valid?
    assert invalid_type.errors.of_kind?(:section_type, :inclusion)

    invalid_status = @property.property_sections.build(
      organization: @organization,
      name: "Bad status",
      section_type: SectionTypes::TOWER,
      status: "frozen"
    )
    assert_not invalid_status.valid?
    assert invalid_status.errors.of_kind?(:status, :inclusion)
  end

  # 9.9
  test "accepts each catalog section_type and status" do
    SectionTypes::ALL.each_with_index do |type, index|
      section = @property.property_sections.create!(
        organization: @organization,
        name: "Type #{type} #{index}",
        section_type: type
      )
      assert_predicate section, :persisted?
    end

    SectionStatuses::ALL.each do |status|
      section = @property.property_sections.create!(
        organization: @organization,
        name: "Status #{status}",
        section_type: SectionTypes::OTHER,
        status: status
      )
      assert_equal status, section.status
    end
  end

  # 9.10
  test "assigns an incrementing default position among siblings" do
    assert_equal 1, @tower.position

    second = @property.property_sections.create!(
      organization: @organization,
      name: "Torre B",
      section_type: SectionTypes::TOWER
    )
    assert_equal 2, second.position
  end

  # 9.15
  test "effective status reflects ancestor and property status" do
    floor = @property.property_sections.create!(
      organization: @organization,
      name: "Piso 1",
      section_type: SectionTypes::FLOOR,
      parent: @tower
    )

    assert_equal SectionStatuses::ACTIVE, floor.effective_status

    @tower.update!(status: SectionStatuses::INACTIVE)
    assert_equal SectionStatuses::INACTIVE, floor.reload.effective_status

    @property.update!(status: PropertyStatuses::ARCHIVED)
    assert_equal SectionStatuses::ARCHIVED, floor.reload.effective_status
  end

  # 9.17
  test "only block, tower and floor are eligible to contain units" do
    eligible = [ SectionTypes::BLOCK, SectionTypes::TOWER, SectionTypes::FLOOR ]

    SectionTypes::ALL.each do |type|
      expected = eligible.include?(type)
      assert_equal expected, SectionTypes.eligible_for_units?(type),
                   "expected eligibility #{expected} for #{type}"
    end

    floor = @property.property_sections.create!(
      organization: @organization,
      name: "Eligible Floor",
      section_type: SectionTypes::FLOOR
    )
    assert_predicate floor, :eligible_for_units?

    sector = @property.property_sections.create!(
      organization: @organization,
      name: "Ineligible Sector",
      section_type: SectionTypes::SECTOR
    )
    assert_not sector.eligible_for_units?
  end
end
