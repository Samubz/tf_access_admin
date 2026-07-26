# frozen_string_literal: true

require "test_helper"

# Remaining improve-units-foundation §8 coverage: edge cases not isolated in
# model/service/policy/controller suites above.
class Units::FoundationCoverageTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "unit-foundation-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @property = create_property(@organization, "Foundation Coverage Property")
    @floor_a = PropertySection.create!(
      organization: @organization,
      residential_property: @property,
      name: "Piso A",
      section_type: SectionTypes::FLOOR
    )
    @floor_b = PropertySection.create!(
      organization: @organization,
      residential_property: @property,
      name: "Piso B",
      section_type: SectionTypes::FLOOR
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "Units::NormalizeIdentifier handles unicode case and whitespace" do
    result = Units::NormalizeIdentifier.call("  Niño 2B ")

    assert_equal "Niño 2B", result.identifier
    # normalized_identifier is a transliterating slug (hierarchical-code-generation),
    # so accents fold to ASCII: "Niño" → "nino".
    assert_equal "nino-2b", result.normalized_identifier
  end

  test "rejects a section from another organization property" do
    foreign_property = ActsAsTenant.with_tenant(@other_organization) do
      create_property(@other_organization, "Foreign Section Property")
    end
    foreign_section = ActsAsTenant.with_tenant(@other_organization) do
      foreign_property.property_sections.create!(
        organization: @other_organization,
        name: "Torre Extranjera",
        section_type: SectionTypes::TOWER
      )
    end

    unit = Unit.new(
      residential_property: @property,
      property_section: foreign_section,
      identifier: "XORG-1",
      unit_type: UnitTypes::APARTMENT
    )

    assert_not unit.valid?
    assert_includes unit.errors[:property_section_id],
                    I18n.t("frontend.admin.units.validations.section_same_property")
  end

  test "allows the same identifier in another property within the tenant" do
    other_property = create_property(@organization, "Foundation Coverage Property Two")
    create_unit(@property, "SHARED-1")

    result = Units::Create.call(
      actor: @tenant_admin,
      property: other_property,
      attributes: { identifier: "SHARED-1", unit_type: UnitTypes::APARTMENT }
    )

    assert result.success?
  end

  test "inactive maintenance and archived units still reserve identifier context" do
    [ UnitStatuses::INACTIVE, UnitStatuses::MAINTENANCE, UnitStatuses::ARCHIVED ].each do |status|
      identifier = "STAT-#{status}"
      unit = create_unit(@property, identifier)
      unit.update!(status: status)

      duplicate = Units::Create.call(
        actor: @tenant_admin,
        property: @property,
        attributes: { identifier: identifier, unit_type: UnitTypes::APARTMENT }
      )

      assert duplicate.invalid?, "expected duplicate rejection for status #{status}"
      assert duplicate.errors[:identifier].present?
      unit.destroy_fully!
    end
  end

  test "moves a unit between eligible sections within the same property" do
    unit = create_unit(@property, "MOVE-SEC-1")
    unit.update!(property_section: @floor_a)

    result = Units::MoveToSection.call(
      actor: @tenant_admin,
      unit: unit,
      section_id: @floor_b.id
    )

    assert result.success?
    assert_equal @floor_b.id, unit.reload.property_section_id
  end

  test "rejects a move when the destination section already has the same identifier" do
    unit = create_unit(@property, "MOVE-CONF-1")
    unit.update!(property_section: @floor_a)
    Units::Create.call(
      actor: @tenant_admin,
      property: @property,
      section_id: @floor_b.id,
      attributes: { identifier: "MOVE-CONF-1", unit_type: UnitTypes::APARTMENT }
    )

    result = Units::MoveToSection.call(
      actor: @tenant_admin,
      unit: unit,
      section_id: @floor_b.id
    )

    assert result.invalid?
    assert result.errors[:identifier].present?
    assert_equal @floor_a.id, unit.reload.property_section_id
  end

  test "move and archive preserve ownerships occupancies and visits" do
    unit = create_unit(@property, "REL-1")
    unit.update!(property_section: @floor_a)
    owner = @tenant_admin.person_for(@organization)
    ownership = UnitOwnership.create!(
      organization: @organization,
      unit: unit,
      person: owner,
      ownership_percentage: 100,
      starts_at: Date.current,
      status: UnitOwnership::STATUS_ACTIVE
    )
    occupant = Person.create!(
      organization: @organization,
      display_name: "Occupant",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    occupancy = UnitOccupancy.create!(
      organization: @organization,
      unit: unit,
      person: occupant,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: Date.current,
      status: OccupancyStatuses::ACTIVE
    )
    visitor = Person.create!(
      organization: @organization,
      display_name: "Visitor",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    visit = Visit.create!(
      organization: @organization,
      unit: unit,
      visitor_person: visitor,
      scheduled_at: 1.day.from_now,
      valid_from: 1.day.from_now,
      status: VisitStatuses::PENDING
    )

    move = Units::MoveToSection.call(
      actor: @tenant_admin,
      unit: unit,
      section_id: @floor_b.id
    )
    assert move.success?

    archive = Units::Archive.call(actor: @tenant_admin, unit: unit)
    assert archive.success?

    assert UnitOwnership.exists?(ownership.id)
    assert UnitOccupancy.exists?(occupancy.id)
    assert Visit.exists?(visit.id)
    assert_equal unit.id, visit.reload.unit_id
    assert_equal unit.id, ownership.reload.unit_id
    assert_equal unit.id, occupancy.reload.unit_id
  end

  test "update rejects disallowed status transitions" do
    unit = create_unit(@property, "STAT-TR-1")

    result = Units::Update.call(
      actor: @tenant_admin,
      unit: unit,
      attributes: { status: "frozen" }
    )

    assert result.invalid?
    assert result.errors.of_kind?(:status, :transition_not_allowed)
  end

  test "translates concurrent unique violations into identifier errors" do
    unit = @property.units.new(
      organization: @organization,
      identifier: "CONC-1",
      unit_type: UnitTypes::APARTMENT
    )
    exception = ActiveRecord::RecordNotUnique.new(
      "PG::UniqueViolation: index_units_on_org_property_normalized_when_no_section"
    )

    unit.send(:register_uniqueness_conflict, exception)

    assert unit.errors[:identifier].present?
  end

  test "serializes concurrent creates so only one unit persists" do
    start_gate = Queue.new
    results = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ActsAsTenant.current_tenant = @organization
          start_gate.pop
          outcome = Units::Create.call(
            actor: @tenant_admin,
            property: @property,
            attributes: { identifier: "CONC-CREATE", unit_type: UnitTypes::APARTMENT }
          )
          results << (outcome.success? ? :success : :invalid)
        end
      end
    end

    2.times { start_gate << true }
    threads.each(&:join)

    outcomes = []
    outcomes << results.pop until results.empty?

    assert_equal 1, outcomes.count(:success)
    assert_equal 1, outcomes.count(:invalid)
    assert_equal 1, @property.units.where(normalized_identifier: "conc-create").count
  end

  test "search respects an authorized policy scope" do
    other_property = create_property(@organization, "Foundation Coverage Property Three")
    visible = create_unit(@property, "SCOPE-1")
    hidden = create_unit(other_property, "SCOPE-2")

    admin = create_staff_user(
      organization: @organization,
      email: "unit-foundation-scope@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property
    )
    scoped = UnitPolicy::Scope.new(admin, Unit.all).resolve

    results = Units::Search.apply(scoped, term: "scope")

    assert_includes results, visible
    assert_not_includes results, hidden
  end
end
