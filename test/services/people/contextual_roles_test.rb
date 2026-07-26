# frozen_string_literal: true

require "test_helper"

module People
  class ContextualRolesTest < ActiveSupport::TestCase
    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization
      @person = Person.create!(
        organization: @organization,
        display_name: "Contextual Roles Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      @unit = create_unit!(identifier: "CTX-ROLES-101")
      @property = @unit.residential_property
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    test "returns owner when person has active ownership" do
      UnitOwnership.create!(
        organization: @organization,
        unit: @unit,
        person: @person,
        ownership_percentage: 50,
        starts_at: Date.current,
        status: UnitOwnership::STATUS_ACTIVE
      )

      roles = ContextualRoles.call(@person)

      assert_includes roles, ContextualRoles::OWNER
      refute_includes roles, ContextualRoles::RESIDENT
    end

    test "returns resident when person has active occupancy" do
      UnitOccupancy.create!(
        organization: @organization,
        unit: @unit,
        person: @person,
        occupancy_type: OccupancyTypes::TENANT,
        status: OccupancyStatuses::ACTIVE,
        starts_at: Time.current
      )

      roles = ContextualRoles.call(@person)

      assert_includes roles, ContextualRoles::RESIDENT
      refute_includes roles, ContextualRoles::OWNER
    end

    test "returns visitor when person has linked visitor profile" do
      VisitorProfile.create!(
        organization: @organization,
        person: @person,
        status: "active"
      )

      roles = ContextualRoles.call(@person)

      assert_includes roles, ContextualRoles::VISITOR
    end

    test "returns system_user when person is linked to user" do
      user = ActsAsTenant.without_tenant do
        User.create!(
          email: "system-user@example.test",
          password: "Password1@",
          password_confirmation: "Password1@",
          name: "System User",
          dni: SecureRandom.hex(4),
          language: Languages::ES,
          confirmed_at: Time.current
        )
      end
      @person.update!(user: user)

      roles = ContextualRoles.call(@person)

      assert_includes roles, ContextualRoles::SYSTEM_USER
    end

    test "returns multiple contextual roles simultaneously" do
      user = ActsAsTenant.without_tenant do
        User.create!(
          email: "multi-role@example.test",
          password: "Password1@",
          password_confirmation: "Password1@",
          name: "Multi Role",
          dni: SecureRandom.hex(4),
          language: Languages::ES,
          confirmed_at: Time.current
        )
      end
      @person.update!(user: user)

      UnitOwnership.create!(
        organization: @organization,
        unit: @unit,
        person: @person,
        ownership_percentage: 100,
        starts_at: Date.current,
        status: UnitOwnership::STATUS_ACTIVE
      )
      UnitOccupancy.create!(
        organization: @organization,
        unit: @unit,
        person: @person,
        occupancy_type: OccupancyTypes::OWNER_RESIDENT,
        status: OccupancyStatuses::ACTIVE,
        starts_at: Time.current
      )
      VisitorProfile.create!(
        organization: @organization,
        person: @person,
        status: "active"
      )

      roles = ContextualRoles.call(@person)

      assert_equal [
        ContextualRoles::OWNER,
        ContextualRoles::RESIDENT,
        ContextualRoles::VISITOR,
        ContextualRoles::SYSTEM_USER
      ], roles
    end

    test "returns empty roles when person has no contextual relationships" do
      roles = ContextualRoles.call(@person)

      assert_empty roles
    end

    test "does not include owner when ownership is inactive" do
      UnitOwnership.create!(
        organization: @organization,
        unit: @unit,
        person: @person,
        ownership_percentage: 100,
        starts_at: Date.current,
        status: "inactive"
      )

      roles = ContextualRoles.call(@person)

      refute_includes roles, ContextualRoles::OWNER
    end

    test "does not include resident when occupancy is inactive" do
      UnitOccupancy.create!(
        organization: @organization,
        unit: @unit,
        person: @person,
        occupancy_type: OccupancyTypes::TENANT,
        status: OccupancyStatuses::INACTIVE,
        starts_at: Time.current
      )

      roles = ContextualRoles.call(@person)

      refute_includes roles, ContextualRoles::RESIDENT
    end

    test "does not include staff roles before assignments exist" do
      UnitOwnership.create!(
        organization: @organization,
        unit: @unit,
        person: @person,
        ownership_percentage: 100,
        starts_at: Date.current,
        status: UnitOwnership::STATUS_ACTIVE
      )

      roles = ContextualRoles.call(@person)

      assert_not roles.intersect?(ContextualRoles::STAFF_ROLES)
    end

    # ---------------------------------------------------------------------------
    # 6.1 — Staff badges from active StaffAssignment
    # ---------------------------------------------------------------------------

    test "returns property_admin when person has active manager assignment" do
      create_staff_assignment!(@person, StaffTypes::MANAGER)

      roles = ContextualRoles.call(@person)

      assert_includes roles, ContextualRoles::PROPERTY_ADMIN
    end

    test "returns concierge when person has active concierge assignment" do
      create_staff_assignment!(@person, StaffTypes::CONCIERGE)

      roles = ContextualRoles.call(@person)

      assert_includes roles, ContextualRoles::CONCIERGE
    end

    test "returns concierge when person has active security assignment" do
      create_staff_assignment!(@person, StaffTypes::SECURITY)

      roles = ContextualRoles.call(@person)

      assert_includes roles, ContextualRoles::CONCIERGE
    end

    test "returns cleaning_staff when person has active cleaning assignment" do
      create_staff_assignment!(@person, StaffTypes::CLEANING)

      roles = ContextualRoles.call(@person)

      assert_includes roles, ContextualRoles::CLEANING_STAFF
    end

    test "returns internal_staff when person has active maintenance assignment" do
      create_staff_assignment!(@person, StaffTypes::MAINTENANCE)

      roles = ContextualRoles.call(@person)

      assert_includes roles, ContextualRoles::INTERNAL_STAFF
    end

    test "returns internal_staff when person has active other assignment" do
      create_staff_assignment!(@person, StaffTypes::OTHER)

      roles = ContextualRoles.call(@person)

      assert_includes roles, ContextualRoles::INTERNAL_STAFF
    end

    test "does not include staff role for inactive assignment" do
      create_staff_assignment!(@person, StaffTypes::MANAGER, status: StaffAssignment::STATUS_INACTIVE)

      roles = ContextualRoles.call(@person)

      refute_includes roles, ContextualRoles::PROPERTY_ADMIN
    end

    test "does not include staff role for expired assignment" do
      create_staff_assignment!(
        @person, StaffTypes::CONCIERGE,
        starts_at: 30.days.ago.to_date,
        ends_at: Date.yesterday
      )

      roles = ContextualRoles.call(@person)

      refute_includes roles, ContextualRoles::CONCIERGE
    end

    test "does not include staff role for future assignment" do
      create_staff_assignment!(
        @person, StaffTypes::MANAGER,
        starts_at: Date.tomorrow,
        ends_at: nil
      )

      roles = ContextualRoles.call(@person)

      refute_includes roles, ContextualRoles::PROPERTY_ADMIN
    end

    test "does not include staff role from another organization" do
      other_organization = organizations(:two)
      other_person = ActsAsTenant.with_tenant(other_organization) do
        Person.create!(
          organization: other_organization,
          display_name: "Other Org Staff",
          person_type: PersonTypes::NATURAL,
          status: PersonStatuses::ACTIVE
        )
      end

      ActsAsTenant.with_tenant(other_organization) do
        property = ResidentialProperty.create!(
          organization: other_organization,
          name: "Other Org Property",
          property_type: PropertyTypes::BUILDING,
          status: "active",
          country: "Chile",
          timezone: "America/Santiago"
        )
        StaffAssignment.create!(
          organization: other_organization,
          person: other_person,
          residential_property: property,
          staff_type: StaffTypes::MANAGER,
          status: StaffAssignment::STATUS_ACTIVE,
          starts_at: Date.current
        )
      end

      roles = ContextualRoles.call(@person)

      refute_includes roles, ContextualRoles::PROPERTY_ADMIN
    end

    # ---------------------------------------------------------------------------
    # 6.2 — batch_for includes staff roles without N+1
    # ---------------------------------------------------------------------------

    test "batch_for includes property_admin role for person with active manager assignment" do
      other_person = Person.create!(
        organization: @organization,
        display_name: "Batch Staff Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )

      create_staff_assignment!(@person, StaffTypes::MANAGER)

      roles_by_person = ContextualRoles.batch_for([ @person, other_person ])

      assert_includes roles_by_person[@person.id], ContextualRoles::PROPERTY_ADMIN
      refute_includes roles_by_person[other_person.id], ContextualRoles::PROPERTY_ADMIN
    end

    test "batch_for includes concierge role from security assignment" do
      create_staff_assignment!(@person, StaffTypes::SECURITY)

      roles_by_person = ContextualRoles.batch_for([ @person ])

      assert_includes roles_by_person[@person.id], ContextualRoles::CONCIERGE
    end

    test "batch_for excludes expired staff assignment" do
      create_staff_assignment!(
        @person, StaffTypes::MANAGER,
        starts_at: 10.days.ago.to_date,
        ends_at: Date.yesterday
      )

      roles_by_person = ContextualRoles.batch_for([ @person ])

      refute_includes roles_by_person[@person.id], ContextualRoles::PROPERTY_ADMIN
    end

    test "batch_for returns contextual roles without per-person queries" do
      other_person = Person.create!(
        organization: @organization,
        display_name: "Batch Other Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )

      UnitOwnership.create!(
        organization: @organization,
        unit: @unit,
        person: @person,
        ownership_percentage: 100,
        starts_at: Date.current,
        status: UnitOwnership::STATUS_ACTIVE
      )
      UnitOccupancy.create!(
        organization: @organization,
        unit: @unit,
        person: other_person,
        occupancy_type: OccupancyTypes::TENANT,
        status: OccupancyStatuses::ACTIVE,
        starts_at: Time.current
      )

      roles_by_person = ContextualRoles.batch_for([ @person, other_person ])

      assert_includes roles_by_person[@person.id], ContextualRoles::OWNER
      refute_includes roles_by_person[@person.id], ContextualRoles::RESIDENT
      assert_includes roles_by_person[other_person.id], ContextualRoles::RESIDENT
      refute_includes roles_by_person[other_person.id], ContextualRoles::OWNER
    end

    test "batch_for returns empty hash for blank collection" do
      assert_equal({}, ContextualRoles.batch_for([]))
    end

    test "person contextual_roles delegates to service" do
      UnitOwnership.create!(
        organization: @organization,
        unit: @unit,
        person: @person,
        ownership_percentage: 100,
        starts_at: Date.current,
        status: UnitOwnership::STATUS_ACTIVE
      )

      assert_equal ContextualRoles.call(@person), @person.contextual_roles
    end

    test "tenant_role is separate from contextual roles" do
      @person.set_tenant_role(AvailableRoles::TENANT_ADMIN)

      assert_equal AvailableRoles::TENANT_ADMIN, @person.tenant_role
      assert_empty @person.contextual_roles
    end

    private

    def create_staff_assignment!(person, staff_type, status: StaffAssignment::STATUS_ACTIVE, starts_at: Date.current, ends_at: nil)
      StaffAssignment.create!(
        organization: @organization,
        person: person,
        residential_property: @property,
        staff_type: staff_type,
        status: status,
        starts_at: starts_at,
        ends_at: ends_at
      )
    end

    def create_unit!(identifier:)
      property = ResidentialProperty.create!(
        organization: @organization,
        name: "Contextual Roles Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      Unit.create!(
        organization: @organization,
        residential_property: property,
        identifier: identifier,
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
    end
  end
end
