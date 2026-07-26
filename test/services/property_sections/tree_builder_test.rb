# frozen_string_literal: true

require "test_helper"

# PropertySections::TreeBuilder presenter (improve-property-sections §9.16):
# property scope, two-level depth, path, ordering, per-node permissions and the
# optional units inclusion.
class PropertySections::TreeBuilderTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "tree-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @property = create_property(@organization, "Tree Property")
    @tower_b = section("Torre B", SectionTypes::TOWER, position: 2)
    @tower_a = section("Torre A", SectionTypes::TOWER, position: 1)
    @floor_2 = section("Piso 2", SectionTypes::FLOOR, position: 2, parent: @tower_a)
    @floor_1 = section("Piso 1", SectionTypes::FLOOR, position: 1, parent: @tower_a)
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "builds an ordered two-level forest scoped to the property" do
    other_property = create_property(@organization, "Other Tree Property")
    section("Foreign", SectionTypes::TOWER, property: other_property)

    tree = builder.tree

    assert_equal [ "Torre A", "Torre B" ], tree.map { |node| node[:name] }
    assert_equal [ "Piso 1", "Piso 2" ], tree.first[:children].map { |node| node[:name] }
    assert_empty tree.last[:children]
    assert_not_includes tree.map { |node| node[:name] }, "Foreign"
  end

  test "computes depth and path and caps depth at two levels" do
    tree = builder.tree
    root = tree.first
    child = root[:children].first

    assert_equal 1, root[:depth]
    assert_equal [ "Torre A" ], root[:path]
    assert_equal 2, child[:depth]
    assert_equal [ "Torre A", "Piso 1" ], child[:path]
    assert(tree.all? { |node| node[:children].all? { |c| c[:children].empty? } })
  end

  test "exposes backend-driven permissions with add_child false for subsections" do
    tree = builder.tree
    root = tree.first
    child = root[:children].first

    assert root[:permissions][:add_child]
    assert_not child[:permissions][:add_child]
    assert root[:permissions][:edit]
    assert root[:permissions][:archive]
  end

  test "marks effective status and disabled under an inactive ancestor" do
    @tower_a.update!(status: SectionStatuses::INACTIVE)

    root = builder.tree.first
    child = root[:children].first

    assert_equal SectionStatuses::INACTIVE, child[:effective_status]
    assert child[:disabled]
    assert_not child[:permissions][:add_child]
  end

  test "includes units only when requested" do
    unit = create_unit(@property, "TREE-101")
    unit.update!(property_section: @floor_1)

    without_units = builder.tree.first[:children].first
    assert_nil without_units[:units]

    with_units = builder(include_units: true).tree.first[:children].first
    assert_equal [ unit.id ], with_units[:units].map { |u| u[:id] }
  end

  test "parent options expose roots only" do
    options = builder.parent_options

    assert_equal [ "Torre A", "Torre B" ], options.map { |option| option[:name] }
    assert(options.all? { |option| option[:depth] == 1 })
  end

  private

  def builder(include_units: false)
    PropertySections::TreeBuilder.new(
      actor: @tenant_admin,
      property: @property,
      include_units: include_units
    )
  end

  def section(name, type, position: nil, parent: nil, property: @property)
    property.property_sections.create!(
      organization: @organization,
      name: name,
      section_type: type,
      position: position,
      parent: parent
    )
  end
end
