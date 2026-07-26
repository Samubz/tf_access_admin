# frozen_string_literal: true

require "test_helper"

# Destructive deletion is blocked for sections with dependencies; archive is the
# only supported retirement operation (improve-property-sections §"Delete vs
# archive strategy"). These tests prove the associations no longer cascade a
# destroy over children, units or visits.
class PropertySectionDestroyProtectionTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property = create_property(@organization, "Destroy Protection Property")
    @tower = @property.property_sections.create!(
      organization: @organization,
      name: "Torre A",
      section_type: SectionTypes::TOWER
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "destroying a section with children does not remove the subtree" do
    floor = @property.property_sections.create!(
      organization: @organization,
      name: "Piso 1",
      section_type: SectionTypes::FLOOR,
      parent: @tower
    )

    assert_not @tower.destroy
    assert @tower.errors.present?
    assert PropertySection.exists?(@tower.id)
    assert PropertySection.exists?(floor.id)
    assert_nil @tower.reload.deleted_at
    assert_nil floor.reload.deleted_at
  end

  test "destroying a section with units does not remove the units" do
    unit = create_unit(@property, "DESTROY-101")
    unit.update!(property_section: @tower)

    assert_not @tower.destroy
    assert Unit.exists?(unit.id)
    assert PropertySection.exists?(@tower.id)
    assert_nil unit.reload.deleted_at
  end

  test "destroying a section with visits does not remove the visits" do
    unit = create_unit(@property, "DESTROY-201")
    unit.update!(property_section: @tower)
    host = create_owner_user(
      organization: @organization,
      email: "destroy-visit-host@example.test",
      unit: unit
    )
    visitor = Person.create!(
      organization: @organization,
      display_name: "Destroy Protection Visitor",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    visit = Visit.create!(
      organization: @organization,
      residential_property: @property,
      property_section: @tower,
      unit: unit,
      visitor_person: visitor,
      scheduled_at: 1.day.from_now,
      valid_from: 1.day.from_now,
      status: VisitStatuses::PENDING
    )

    assert_not @tower.destroy
    assert Visit.exists?(visit.id)
    assert PropertySection.exists?(@tower.id)
  end

  test "archive remains non-destructive and idempotent" do
    actor = create_user_for_organization(
      organization: @organization,
      email: "destroy-archive-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    floor = @property.property_sections.create!(
      organization: @organization,
      name: "Piso 1",
      section_type: SectionTypes::FLOOR,
      parent: @tower
    )

    result = PropertySections::Archive.call(actor: actor, section: @tower)
    assert result.success?
    assert_equal SectionStatuses::ARCHIVED, @tower.reload.status
    assert PropertySection.exists?(floor.id)
    assert_nil @tower.deleted_at

    repeat = PropertySections::Archive.call(actor: actor, section: @tower)
    assert repeat.noop?
  end
end
