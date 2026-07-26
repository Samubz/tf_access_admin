# frozen_string_literal: true

require "test_helper"

module OperationalRoles
  class AssignmentServicesTest < ActiveSupport::TestCase
    setup do
      @organization = organizations(:one)
      @other_organization = organizations(:two)
      ActsAsTenant.current_tenant = @organization

      @property = ResidentialProperty.create!(
        organization: @organization,
        name: "Assignment Service Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )

      @other_property = ActsAsTenant.with_tenant(@other_organization) do
        ResidentialProperty.create!(
          organization: @other_organization,
          name: "Other Org Property",
          property_type: PropertyTypes::BUILDING,
          status: "active",
          country: "Chile",
          timezone: "America/Santiago"
        )
      end

      # actor — used as the performing user; doesn't need a property role
      @actor = create_user_for_organization(
        organization: @organization,
        email: "op-roles-actor@example.test",
        role: AvailableRoles::TENANT_ADMIN
      )

      # person linked to a User (required for roles that need system access)
      @user_with_person = create_user_for_organization(
        organization: @organization,
        email: "op-roles-staff@example.test",
        role: AvailableRoles::CLIENT
      )
      @person_with_user = @user_with_person.person_for(@organization)

      # person NOT linked to a User (for roles that do not require system access)
      @person_no_user = Person.create!(
        organization: @organization,
        display_name: "No User Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
      Current.reset
    end

    # ---------------------------------------------------------------------------
    # 8.1 — AssignPropertyAdmin
    # ---------------------------------------------------------------------------

    test "AssignPropertyAdmin creates active StaffAssignment with manager type" do
      result = AssignPropertyAdmin.new(
        actor: @actor,
        person: @person_with_user,
        organization: @organization,
        residential_property: @property
      ).call

      assert result[:success]
      assert_equal StaffTypes::MANAGER, result[:assignment].staff_type
      assert_equal StaffAssignment::STATUS_ACTIVE, result[:assignment].status
      assert_equal @property.id, result[:assignment].residential_property_id
    end

    test "AssignPropertyAdmin reactivates an existing inactive assignment" do
      existing = StaffAssignment.create!(
        organization: @organization,
        person: @person_with_user,
        residential_property: @property,
        staff_type: StaffTypes::MANAGER,
        status: StaffAssignment::STATUS_INACTIVE,
        starts_at: 30.days.ago.to_date
      )

      result = AssignPropertyAdmin.new(
        actor: @actor,
        person: @person_with_user,
        organization: @organization,
        residential_property: @property
      ).call

      assert result[:success]
      assert_equal existing.id, result[:assignment].id
      assert_equal StaffAssignment::STATUS_ACTIVE, result[:assignment].reload.status
    end

    test "AssignPropertyAdmin fails when person has no linked user" do
      result = AssignPropertyAdmin.new(
        actor: @actor,
        person: @person_no_user,
        organization: @organization,
        residential_property: @property
      ).call

      refute result[:success]
      assert_nil result[:assignment]
      assert result[:errors].any? { |e| e.include?("linked user") }
    end

    test "AssignPropertyAdmin fails when property belongs to another organization" do
      result = AssignPropertyAdmin.new(
        actor: @actor,
        person: @person_with_user,
        organization: @organization,
        residential_property: @other_property
      ).call

      refute result[:success]
      assert result[:errors].any? { |e| e.include?("organization") }
    end

    test "AssignPropertyAdmin assignment is scoped to the property, never global" do
      AssignPropertyAdmin.new(
        actor: @actor,
        person: @person_with_user,
        organization: @organization,
        residential_property: @property
      ).call

      assert_not_nil StaffAssignment.last.residential_property_id
    end

    # ---------------------------------------------------------------------------
    # 8.2 — AssignConcierge
    # ---------------------------------------------------------------------------

    test "AssignConcierge creates active StaffAssignment with concierge type" do
      result = AssignConcierge.new(
        actor: @actor,
        person: @person_with_user,
        organization: @organization,
        residential_property: @property
      ).call

      assert result[:success]
      assert_equal StaffTypes::CONCIERGE, result[:assignment].staff_type
      assert_equal StaffAssignment::STATUS_ACTIVE, result[:assignment].status
    end

    test "AssignConcierge fails when person has no linked user" do
      result = AssignConcierge.new(
        actor: @actor,
        person: @person_no_user,
        organization: @organization,
        residential_property: @property
      ).call

      refute result[:success]
      assert result[:errors].any? { |e| e.include?("linked user") }
    end

    test "AssignConcierge fails for cross-organization property" do
      result = AssignConcierge.new(
        actor: @actor,
        person: @person_with_user,
        organization: @organization,
        residential_property: @other_property
      ).call

      refute result[:success]
      assert result[:errors].any? { |e| e.include?("organization") }
    end

    test "AssignConcierge reactivates an existing inactive assignment" do
      existing = StaffAssignment.create!(
        organization: @organization,
        person: @person_with_user,
        residential_property: @property,
        staff_type: StaffTypes::CONCIERGE,
        status: StaffAssignment::STATUS_INACTIVE,
        starts_at: 10.days.ago.to_date
      )

      result = AssignConcierge.new(
        actor: @actor,
        person: @person_with_user,
        organization: @organization,
        residential_property: @property
      ).call

      assert result[:success]
      assert_equal existing.id, result[:assignment].id
      assert_equal StaffAssignment::STATUS_ACTIVE, result[:assignment].reload.status
    end

    # ---------------------------------------------------------------------------
    # 8.3 — AssignInternalStaff
    # ---------------------------------------------------------------------------

    test "AssignInternalStaff creates assignment with cleaning type" do
      result = AssignInternalStaff.new(
        actor: @actor,
        person: @person_no_user,
        organization: @organization,
        residential_property: @property,
        staff_type: StaffTypes::CLEANING
      ).call

      assert result[:success]
      assert_equal StaffTypes::CLEANING, result[:assignment].staff_type
      assert_equal StaffAssignment::STATUS_ACTIVE, result[:assignment].status
    end

    test "AssignInternalStaff creates assignment with maintenance type" do
      result = AssignInternalStaff.new(
        actor: @actor,
        person: @person_no_user,
        organization: @organization,
        residential_property: @property,
        staff_type: StaffTypes::MAINTENANCE
      ).call

      assert result[:success]
      assert_equal StaffTypes::MAINTENANCE, result[:assignment].staff_type
    end

    test "AssignInternalStaff creates assignment with other type" do
      result = AssignInternalStaff.new(
        actor: @actor,
        person: @person_no_user,
        organization: @organization,
        residential_property: @property,
        staff_type: StaffTypes::OTHER
      ).call

      assert result[:success]
      assert_equal StaffTypes::OTHER, result[:assignment].staff_type
    end

    test "AssignInternalStaff succeeds without linked user" do
      result = AssignInternalStaff.new(
        actor: @actor,
        person: @person_no_user,
        organization: @organization,
        residential_property: @property,
        staff_type: StaffTypes::CLEANING
      ).call

      assert result[:success]
    end

    test "AssignInternalStaff rejects manager staff_type" do
      result = AssignInternalStaff.new(
        actor: @actor,
        person: @person_no_user,
        organization: @organization,
        residential_property: @property,
        staff_type: StaffTypes::MANAGER
      ).call

      refute result[:success]
      assert result[:errors].any? { |e| e.include?("staff_type") }
    end

    test "AssignInternalStaff rejects concierge staff_type" do
      result = AssignInternalStaff.new(
        actor: @actor,
        person: @person_no_user,
        organization: @organization,
        residential_property: @property,
        staff_type: StaffTypes::CONCIERGE
      ).call

      refute result[:success]
      assert result[:errors].any? { |e| e.include?("staff_type") }
    end

    test "AssignInternalStaff fails for cross-organization property" do
      result = AssignInternalStaff.new(
        actor: @actor,
        person: @person_no_user,
        organization: @organization,
        residential_property: @other_property,
        staff_type: StaffTypes::CLEANING
      ).call

      refute result[:success]
      assert result[:errors].any? { |e| e.include?("organization") }
    end

    # ---------------------------------------------------------------------------
    # 8.4 — RevokeAssignment
    # ---------------------------------------------------------------------------

    test "RevokeAssignment deactivates an active assignment" do
      assignment = StaffAssignment.create!(
        organization: @organization,
        person: @person_with_user,
        residential_property: @property,
        staff_type: StaffTypes::MANAGER,
        status: StaffAssignment::STATUS_ACTIVE,
        starts_at: Date.current
      )

      result = RevokeAssignment.new(actor: @actor, assignment: assignment).call

      assert result[:success]
      assert_equal StaffAssignment::STATUS_INACTIVE, assignment.reload.status
      assert_equal Date.current, assignment.ends_at
    end

    test "RevokeAssignment sets ends_at to today when not previously set" do
      assignment = StaffAssignment.create!(
        organization: @organization,
        person: @person_with_user,
        residential_property: @property,
        staff_type: StaffTypes::CONCIERGE,
        status: StaffAssignment::STATUS_ACTIVE,
        starts_at: 10.days.ago.to_date
      )

      RevokeAssignment.new(actor: @actor, assignment: assignment).call

      assert_equal Date.current, assignment.reload.ends_at
    end

    test "RevokeAssignment preserves an earlier ends_at" do
      ends_at = Date.current - 1
      assignment = StaffAssignment.create!(
        organization: @organization,
        person: @person_with_user,
        residential_property: @property,
        staff_type: StaffTypes::CONCIERGE,
        status: StaffAssignment::STATUS_ACTIVE,
        starts_at: 30.days.ago.to_date,
        ends_at: ends_at
      )

      RevokeAssignment.new(actor: @actor, assignment: assignment).call

      assert_equal ends_at, assignment.reload.ends_at
    end

    test "RevokeAssignment fails when assignment is already inactive" do
      assignment = StaffAssignment.create!(
        organization: @organization,
        person: @person_with_user,
        residential_property: @property,
        staff_type: StaffTypes::MANAGER,
        status: StaffAssignment::STATUS_INACTIVE,
        starts_at: Date.current
      )

      result = RevokeAssignment.new(actor: @actor, assignment: assignment).call

      refute result[:success]
      assert result[:errors].any? { |e| e.include?("inactive") }
    end

    # ---------------------------------------------------------------------------
    # 8.5 — Revoked assignment no longer grants resolver capabilities
    # ---------------------------------------------------------------------------

    test "revoked assignment no longer grants capabilities in the resolver" do
      assignment = StaffAssignment.create!(
        organization: @organization,
        person: @person_with_user,
        residential_property: @property,
        staff_type: StaffTypes::MANAGER,
        status: StaffAssignment::STATUS_ACTIVE,
        starts_at: Date.current
      )

      RevokeAssignment.new(actor: @actor, assignment: assignment).call

      resolver = Authorization::Resolver.new(
        user: @user_with_person,
        organization: @organization,
        property: @property
      )
      refute resolver.allowed?(:manage_units)
      refute resolver.allowed?(:manage_ownerships)
    end

    # ---------------------------------------------------------------------------
    # Audit trail
    # ---------------------------------------------------------------------------

    test "AssignPropertyAdmin generates an audit record on create" do
      assert_difference -> { Audited::Audit.count } do
        AssignPropertyAdmin.new(
          actor: @actor,
          person: @person_with_user,
          organization: @organization,
          residential_property: @property
        ).call
      end
    end

    test "RevokeAssignment generates an audit record" do
      assignment = StaffAssignment.create!(
        organization: @organization,
        person: @person_with_user,
        residential_property: @property,
        staff_type: StaffTypes::CONCIERGE,
        status: StaffAssignment::STATUS_ACTIVE,
        starts_at: Date.current
      )

      assert_difference -> { Audited::Audit.count } do
        RevokeAssignment.new(actor: @actor, assignment: assignment).call
      end
    end
  end
end
