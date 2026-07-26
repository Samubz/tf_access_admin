# frozen_string_literal: true

require "test_helper"

class DomainCodes::DeriveSectionCodeTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @actor = create_user_for_organization(
      organization: @organization, email: "derive-section-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @property = ResidentialProperty.create!(
      organization: @organization, name: "Torre Sur", property_type: PropertyTypes::BUILDING,
      status: PropertyStatuses::ACTIVE, country: "Chile", timezone: "America/Santiago",
      code: "bld-torre-sur"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "root section derives {property_code}-{type_abbrev}-{name_slug}" do
    result = PropertySections::Create.call(
      actor: @actor, property: @property,
      attributes: { name: "Torre Á", section_type: SectionTypes::TOWER }
    )

    assert result.success?
    assert_equal "bld-torre-sur-tor-torre-a", result.section.code
  end

  test "child section derives {parent_code}-{name_slug}" do
    parent = PropertySections::Create.call(
      actor: @actor, property: @property,
      attributes: { name: "Torre A", section_type: SectionTypes::TOWER }
    ).section

    child = PropertySections::Create.call(
      actor: @actor, property: @property, parent: parent,
      attributes: { name: "Piso 1", section_type: SectionTypes::FLOOR }
    ).section

    assert_equal "#{parent.code}-piso-1", child.code
    assert_equal "bld-torre-sur-tor-torre-a-piso-1", child.code
  end

  test "colliding root codes get a numeric suffix" do
    first = create_root("Torre A")
    second = create_root("Torre Á") # same slug torre-a

    assert_equal "bld-torre-sur-tor-torre-a", first.code
    assert_equal "bld-torre-sur-tor-torre-a-2", second.code
  end

  test "client-submitted code is ignored" do
    result = PropertySections::Create.call(
      actor: @actor, property: @property,
      attributes: { name: "Torre A", section_type: SectionTypes::TOWER, code: "CUSTOM" }
    )

    assert_equal "bld-torre-sur-tor-torre-a", result.section.code
  end

  test "batch creation derives a code per section" do
    result = PropertySections::CreateBatch.call(
      actor: @actor, property: @property, section_type: SectionTypes::TOWER,
      prefix: "Torre", suffix_type: :letter, count: 3
    )

    assert result.success?
    assert_equal(
      [ "bld-torre-sur-tor-torre-a", "bld-torre-sur-tor-torre-b", "bld-torre-sur-tor-torre-c" ],
      result.sections.map(&:code)
    )
  end

  private

  def create_root(name)
    PropertySections::Create.call(
      actor: @actor, property: @property,
      attributes: { name: name, section_type: SectionTypes::TOWER }
    ).section
  end
end
