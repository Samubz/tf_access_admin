# frozen_string_literal: true

# == Schema Information
#
# Table name: units
#
#  id                      :uuid             not null, primary key
#  area_m2                 :decimal(10, 2)
#  code                    :string
#  deleted_at              :datetime
#  display_name            :string
#  identifier              :string           not null
#  metadata                :jsonb            not null
#  normalized_identifier   :string           not null
#  status                  :string           default("available"), not null
#  unit_type               :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  organization_id         :uuid             not null
#  property_section_id     :uuid
#  residential_property_id :uuid             not null
#
# Indexes
#
#  idx_on_organization_id_residential_property_id_stat_47cefd6e3a  (organization_id,residential_property_id,status)
#  idx_units_on_org_property_normalized_identifier_lookup          (organization_id,residential_property_id,normalized_identifier) WHERE (deleted_at IS NULL)
#  idx_units_unique_code_in_property_root                          (organization_id,residential_property_id,code) UNIQUE WHERE ((deleted_at IS NULL) AND (property_section_id IS NULL) AND (code IS NOT NULL))
#  idx_units_unique_code_in_section                                (organization_id,residential_property_id,property_section_id,code) UNIQUE WHERE ((deleted_at IS NULL) AND (property_section_id IS NOT NULL) AND (code IS NOT NULL))
#  index_units_on_deleted_at                                       (deleted_at)
#  index_units_on_metadata                                         (metadata) USING gin
#  index_units_on_org_property_normalized_when_no_section          (organization_id,residential_property_id,normalized_identifier) UNIQUE WHERE ((property_section_id IS NULL) AND (deleted_at IS NULL))
#  index_units_on_org_property_section_normalized_when_section     (organization_id,residential_property_id,property_section_id,normalized_identifier) UNIQUE WHERE ((property_section_id IS NOT NULL) AND (deleted_at IS NULL))
#  index_units_on_organization_id                                  (organization_id)
#  index_units_on_organization_id_and_property_section_id          (organization_id,property_section_id)
#  index_units_on_property_section_id                              (property_section_id)
#  index_units_on_residential_property_id                          (residential_property_id)
#
# Foreign Keys
#
#  fk_rails_...                                         (organization_id => organizations.id)
#  fk_rails_...                                         (property_section_id => property_sections.id)
#  fk_rails_...                                         (residential_property_id => residential_properties.id)
#  fk_units_organization_residential_property_coherent  ([organization_id, residential_property_id] => residential_properties[organization_id, id])
#
require "test_helper"

# Model-level contract for Unit (improve-units-foundation §1): identity,
# placement coherence, catalogs, uniqueness, area and metadata guards.
class UnitTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization

    @property = create_property(@organization, "Unit Model Property")
    @tower = @property.property_sections.create!(
      organization: @organization,
      name: "Torre A",
      section_type: SectionTypes::TOWER
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  def build_unit(**attributes)
    Unit.new({
      residential_property: @property,
      identifier: "101",
      unit_type: UnitTypes::APARTMENT
    }.merge(attributes))
  end

  # 1.1 / 1.2
  test "valid unit derives organization from property" do
    unit = build_unit(organization: nil)

    assert unit.valid?
    assert_equal @organization.id, unit.organization_id
    assert_equal UnitStatuses::AVAILABLE, unit.status
  end

  # 1.1
  test "requires residential property" do
    unit = Unit.new(identifier: "101", unit_type: UnitTypes::APARTMENT)

    assert_not unit.valid?
    assert unit.errors.of_kind?(:residential_property, :blank)
  end

  # 1.3
  test "residential property is immutable" do
    unit = build_unit.tap(&:save!)
    other_property = create_property(@organization, "Another Property")
    unit.residential_property = other_property

    assert_not unit.valid?
    assert_includes unit.errors[:residential_property_id],
                    I18n.t("frontend.admin.units.validations.residential_property_immutable")
  end

  # 1.4
  test "rejects a section from another property" do
    other_property = create_property(@organization, "Other Property")
    foreign_section = other_property.property_sections.create!(
      organization: @organization, name: "Torre X", section_type: SectionTypes::TOWER
    )

    unit = build_unit(property_section: foreign_section)

    assert_not unit.valid?
    assert_includes unit.errors[:property_section_id],
                    I18n.t("frontend.admin.units.validations.section_same_property")
  end

  # 1.4 — unresolvable section is not silently treated as "no section"
  test "rejects a non-existent section id" do
    unit = build_unit(property_section_id: SecureRandom.uuid)

    assert_not unit.valid?
    assert_includes unit.errors[:property_section_id],
                    I18n.t("frontend.admin.units.validations.section_invalid")
  end

  # 1.5
  test "rejects an inactive or archived section" do
    @tower.update!(status: SectionStatuses::ARCHIVED)
    unit = build_unit(property_section: @tower)

    assert_not unit.valid?
    assert_includes unit.errors[:property_section_id],
                    I18n.t("frontend.admin.units.validations.section_not_operative")
  end

  # 1.6
  test "accepts an eligible active section and rejects a non-eligible one" do
    assert build_unit(property_section: @tower).valid?

    sector = @property.property_sections.create!(
      organization: @organization, name: "Sector Norte", section_type: SectionTypes::SECTOR
    )
    unit = build_unit(property_section: sector)

    assert_not unit.valid?
    assert_includes unit.errors[:property_section_id],
                    I18n.t("frontend.admin.units.validations.section_not_eligible")
  end

  # 1.7
  test "normalizes identifier canonically" do
    unit = build_unit(identifier: "  Torre A 101 ")
    unit.save!

    assert_equal "Torre A 101", unit.identifier
    assert_equal "torre-a-101", unit.normalized_identifier
  end

  # 1.8
  test "rejects a duplicate identifier in the same section" do
    build_unit(identifier: "101", property_section: @tower).save!
    duplicate = build_unit(identifier: "101", property_section: @tower)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:identifier],
                    I18n.t("frontend.admin.units.validations.identifier_taken")
  end

  # 1.8
  test "rejects a duplicate identifier without section in the same property" do
    build_unit(identifier: "101").save!
    duplicate = build_unit(identifier: "101")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:identifier],
                    I18n.t("frontend.admin.units.validations.identifier_taken")
  end

  # 1.9
  test "allows the same identifier under a different section" do
    floor = @property.property_sections.create!(
      organization: @organization, name: "Piso 1", section_type: SectionTypes::FLOOR
    )
    build_unit(identifier: "101", property_section: @tower).save!

    assert build_unit(identifier: "101", property_section: floor).valid?
  end

  # 1.9 — and a unit without section coexists with a sectioned one
  test "allows a sectioned and an unsectioned unit with the same identifier" do
    build_unit(identifier: "101", property_section: @tower).save!

    assert build_unit(identifier: "101").valid?
  end

  # 1.10 / 1.16
  test "requires the canonical catalog when unit_type is written" do
    canonical = build_unit(unit_type: UnitTypes::COMMON_AREA)
    assert canonical.valid?

    legacy = build_unit(unit_type: UnitTypes::STUDIO)
    assert_not legacy.valid?
    assert_includes legacy.errors[:unit_type],
                    I18n.t("frontend.admin.units.validations.unit_type_invalid")
  end

  # 1.15 — a legacy type already persisted does not block an unrelated update
  test "tolerates a legacy unit_type on an unrelated update" do
    unit = build_unit
    unit.save!
    unit.update_column(:unit_type, UnitTypes::STUDIO)
    unit.reload

    unit.display_name = "Renamed"
    assert unit.valid?, unit.errors.full_messages.to_sentence
    assert unit.save
  end

  # 1.11
  test "validates status against the catalog including archived" do
    assert build_unit(status: UnitStatuses::ARCHIVED).valid?

    invalid = build_unit(status: "frozen")
    assert_not invalid.valid?
    assert invalid.errors.of_kind?(:status, :inclusion)
  end

  # 1.12
  test "accepts a positive area and rejects zero or negative" do
    assert build_unit(area_m2: 45.5).valid?
    assert build_unit(area_m2: nil).valid?

    assert_not build_unit(area_m2: 0).valid?
    assert_not build_unit(area_m2: -1).valid?
  end

  # 1.13 / 1.14
  test "strips reserved keys from metadata so it cannot override structural fields" do
    unit = build_unit(metadata: {
      "organization_id" => @other_organization.id,
      "property_section_id" => SecureRandom.uuid,
      "status" => "archived",
      "color" => "blue"
    })
    unit.save!

    assert_equal({ "color" => "blue" }, unit.metadata)
    assert_equal @organization.id, unit.organization_id
    assert_equal UnitStatuses::AVAILABLE, unit.status
  end

  # 3.2 — the same identifier may coexist in another organization
  test "allows the same identifier in another organization" do
    build_unit(identifier: "101", property_section: @tower).save!

    ActsAsTenant.with_tenant(@other_organization) do
      other_property = create_property(@other_organization, "Other Org Property")
      other_unit = Unit.new(
        residential_property: other_property,
        identifier: "101",
        unit_type: UnitTypes::APARTMENT
      )

      assert other_unit.valid?, other_unit.errors.full_messages.to_sentence
    end
  end

  # 8.2 — metadata cannot grant authorization
  test "strips authorization keys from metadata so it cannot grant access" do
    unit = build_unit(metadata: {
      "role" => "tenant_admin",
      "roles" => [ "property_admin" ],
      "capabilities" => [ "manage_units" ],
      "permission" => "all",
      "authorization" => "granted",
      "access" => "granted",
      "note" => "ok"
    })
    unit.save!

    assert_equal({ "note" => "ok" }, unit.metadata)
  end
end
