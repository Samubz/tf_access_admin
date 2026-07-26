# frozen_string_literal: true

require "test_helper"

class OperationalPoliciesTest < ActiveSupport::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property_p = create_property(@organization, "Operational Policy P")
    @property_q = create_property(@organization, "Operational Policy Q")
    @unit_p = create_unit(@property_p, "OP-P-101")
    @unit_q = create_unit(@property_q, "OP-Q-101")
    @section_p = PropertySection.create!(
      organization: @organization,
      residential_property: @property_p,
      name: "Section P",
      section_type: SectionTypes::TOWER
    )

    @related_person = Person.create!(
      organization: @organization,
      display_name: "Related Person",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    UnitOwnership.create!(
      organization: @organization,
      unit: @unit_p,
      person: @related_person,
      ownership_percentage: 100,
      starts_at: Date.current,
      status: UnitOwnership::STATUS_ACTIVE
    )

    @ownership_p = @related_person.unit_ownerships.first
    @occupancy_p = UnitOccupancy.create!(
      organization: @organization,
      unit: @unit_p,
      person: @related_person,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: Time.zone.now,
      status: OccupancyStatuses::ACTIVE
    )

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "op-policies-tenant-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @property_admin_p = create_staff_user(
      organization: @organization,
      email: "op-policies-property-admin@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property_p
    )
    @concierge_p = create_staff_user(
      organization: @organization,
      email: "op-policies-concierge@example.test",
      staff_type: StaffTypes::CONCIERGE,
      property: @property_p
    )
    @client = create_user_for_organization(
      organization: @organization,
      email: "op-policies-client@example.test",
      role: AvailableRoles::CLIENT
    )
    @owner = create_owner_user(
      organization: @organization,
      email: "op-policies-owner@example.test",
      unit: @unit_q
    )
    @owner_person = @owner.person_for(@organization)

    @other_org_property = ActsAsTenant.with_tenant(@other_organization) do
      create_property(@other_organization, "Other Org Operational Property")
    end
    @other_org_unit = ActsAsTenant.with_tenant(@other_organization) do
      create_unit(@other_org_property, "OTHER-101")
    end
    @other_org_person = ActsAsTenant.with_tenant(@other_organization) do
      Person.create!(
        organization: @other_organization,
        display_name: "Other Org Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
    end
    @bulk_import_p = BulkImport.create!(
      organization: @organization,
      created_by: @tenant_admin,
      import_type: BulkImport::IMPORT_TYPES[:units],
      residential_property: @property_p,
      status: "draft"
    )
    @bulk_import_q = BulkImport.create!(
      organization: @organization,
      created_by: @tenant_admin,
      import_type: BulkImport::IMPORT_TYPES[:units],
      residential_property: @property_q,
      status: "draft"
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "tenant admin retains organization-wide access within organization" do
    assert ResidentialPropertyPolicy.new(@tenant_admin, @property_p).show?
    assert UnitPolicy.new(@tenant_admin, @unit_q).show?
    assert UnitOwnershipPolicy.new(@tenant_admin, @ownership_p).create?
    assert UserPolicy.new(@tenant_admin, @client).index?
    assert BulkImportPolicy.new(@tenant_admin, @bulk_import_q).update?
  end

  test "tenant admin cannot access another organization" do
    refute ResidentialPropertyPolicy.new(@tenant_admin, @other_org_property).show?
    refute PersonPolicy.new(@tenant_admin, @other_org_person).show?
  end

  test "tenant admin can create update and archive properties in own organization" do
    policy_p = ResidentialPropertyPolicy.new(@tenant_admin, @property_p)

    assert policy_p.update?
    assert policy_p.archive?
    assert policy_p.destroy?
    assert ResidentialPropertyPolicy.new(@tenant_admin, ResidentialProperty).create?
  end

  test "tenant admin cannot create update or archive another organization property" do
    policy = ResidentialPropertyPolicy.new(@tenant_admin, @other_org_property)

    refute policy.show?
    refute policy.update?
    refute policy.archive?
    refute policy.destroy?
  end

  test "property admin of P can view and update assigned property only" do
    policy_p = ResidentialPropertyPolicy.new(@property_admin_p, @property_p)
    policy_q = ResidentialPropertyPolicy.new(@property_admin_p, @property_q)

    assert policy_p.show?
    assert policy_p.update?
    refute policy_p.create?
    refute policy_p.archive?
    refute policy_p.destroy?

    refute policy_q.show?
    refute policy_q.update?
    refute policy_q.create?
    refute policy_q.archive?
  end

  test "property admin of P can manage allowed resources on P" do
    assert ResidentialPropertyPolicy.new(@property_admin_p, @property_p).show?
    assert UnitPolicy.new(@property_admin_p, @unit_p).show?
    assert UnitPolicy.new(@property_admin_p, @unit_p).update?
    assert PersonPolicy.new(@property_admin_p, @related_person).show?
    assert UnitOwnershipPolicy.new(@property_admin_p, @ownership_p).update?
    assert UnitOccupancyPolicy.new(@property_admin_p, @occupancy_p).update?
    assert BulkImportPolicy.new(@property_admin_p, @bulk_import_p).update?
  end

  test "property admin of P cannot access resources on Q" do
    refute ResidentialPropertyPolicy.new(@property_admin_p, @property_q).show?
    refute UnitPolicy.new(@property_admin_p, @unit_q).show?
    refute UnitPolicy.new(@property_admin_p, @unit_q).update?
    refute BulkImportPolicy.new(@property_admin_p, @bulk_import_q).update?
  end

  test "concierge of P cannot manage administrative resources" do
    refute UnitPolicy.new(@concierge_p, @unit_p).update?
    refute PersonPolicy.new(@concierge_p, @related_person).show?
    refute UnitOwnershipPolicy.new(@concierge_p, @ownership_p).create?
    refute UnitOccupancyPolicy.new(@concierge_p, @occupancy_p).create?
    refute UserPolicy.new(@concierge_p, @client).index?
    refute BulkImportPolicy.new(@concierge_p, @bulk_import_p).update?
  end

  test "concierge of P cannot access resources on Q" do
    refute UnitPolicy.new(@concierge_p, @unit_q).show?
    refute BulkImportPolicy.new(@concierge_p, @bulk_import_q).update?
  end

  test "owner can view own unit context without admin permissions" do
    assert UnitPolicy.new(@owner, @unit_q).show?
    refute UnitPolicy.new(@owner, @unit_q).update?
    refute UnitPolicy.new(@owner, @unit_p).show?
    refute UnitOwnershipPolicy.new(@owner, @ownership_p).create?
    refute UserPolicy.new(@owner, @client).index?
  end

  test "owner can view own person profile without admin permissions" do
    assert PersonPolicy.new(@owner, @owner_person).show?
    refute PersonPolicy.new(@owner, @owner_person).update?
    refute PersonPolicy.new(@owner, @related_person).show?
  end

  test "client without assignments gets empty scopes and denied mutations" do
    refute UnitPolicy.new(@client, @unit_p).show?
    refute PersonPolicy.new(@client, @related_person).show?
    refute BulkImportPolicy.new(@client, @bulk_import_p).create?

    assert_empty ResidentialPropertyPolicy::Scope.new(@client, ResidentialProperty.all).resolve
    assert_empty UnitPolicy::Scope.new(@client, Unit.all).resolve
    assert_empty PersonPolicy::Scope.new(@client, Person.all).resolve
  end

  test "unit ownership policy denies mismatched unit and person organizations" do
    mismatched = UnitOwnership.new(
      organization: @organization,
      unit: @unit_p,
      person: @other_org_person,
      ownership_percentage: 50,
      starts_at: Date.current,
      status: UnitOwnership::STATUS_ACTIVE
    )

    refute UnitOwnershipPolicy.new(@tenant_admin, mismatched).create?
  end

  test "unit occupancy policy denies mismatched unit and person organizations" do
    mismatched = UnitOccupancy.new(
      organization: @organization,
      unit: @unit_p,
      person: @other_org_person,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: Time.zone.now,
      status: OccupancyStatuses::ACTIVE
    )

    refute UnitOccupancyPolicy.new(@tenant_admin, mismatched).create?
  end

  test "person policy denies full profile to concierge without view_people" do
    refute PersonPolicy.new(@concierge_p, @related_person).show?
  end

  test "policy scopes exclude cross organization records" do
    other_org_ownership = ActsAsTenant.without_tenant do
      other_person = Person.create!(
        organization: @other_organization,
        display_name: "Scope Other Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      UnitOwnership.create!(
        organization: @other_organization,
        unit: @other_org_unit,
        person: other_person,
        ownership_percentage: 100,
        starts_at: Date.current,
        status: UnitOwnership::STATUS_ACTIVE
      )
    end

    resolved = UnitOwnershipPolicy::Scope.new(@tenant_admin, UnitOwnership.all).resolve
    assert_includes resolved, @ownership_p
    refute_includes resolved, other_org_ownership
  end

  test "property admin scope is limited to assigned property" do
    resolved = ResidentialPropertyPolicy::Scope.new(@property_admin_p, ResidentialProperty.all).resolve

    assert_includes resolved, @property_p
    refute_includes resolved, @property_q
    refute_includes resolved, @other_org_property
  end

  test "inactive property admin assignment grants no residential property access" do
    inactive_admin = create_user_for_organization(
      organization: @organization,
      email: "op-policies-inactive-admin@example.test",
      role: AvailableRoles::CLIENT
    )
    StaffAssignment.create!(
      organization: @organization,
      person: inactive_admin.person_for(@organization),
      residential_property: @property_p,
      staff_type: StaffTypes::MANAGER,
      status: StaffAssignment::STATUS_INACTIVE,
      starts_at: Date.current
    )

    policy = ResidentialPropertyPolicy.new(inactive_admin, @property_p)

    refute policy.show?
    refute policy.update?
    assert_empty ResidentialPropertyPolicy::Scope.new(inactive_admin, ResidentialProperty.all).resolve
  end

  test "expired property admin assignment grants no residential property access" do
    expired_admin = create_user_for_organization(
      organization: @organization,
      email: "op-policies-expired-admin@example.test",
      role: AvailableRoles::CLIENT
    )
    StaffAssignment.create!(
      organization: @organization,
      person: expired_admin.person_for(@organization),
      residential_property: @property_p,
      staff_type: StaffTypes::MANAGER,
      status: StaffAssignment::STATUS_ACTIVE,
      starts_at: 30.days.ago.to_date,
      ends_at: Date.current - 1.day
    )

    policy = ResidentialPropertyPolicy.new(expired_admin, @property_p)

    refute policy.show?
    refute policy.update?
  end

  test "global manager role without staff assignment does not grant property admin access" do
    global_manager = create_user_for_organization(
      organization: @organization,
      email: "op-policies-global-manager@example.test",
      role: AvailableRoles::MANAGER
    )

    policy = ResidentialPropertyPolicy.new(global_manager, @property_p)

    refute policy.show?
    refute policy.update?
    refute policy.create?
    refute policy.archive?
  end

  test "bulk import scope respects property access" do
    tenant_scope = BulkImportPolicy::Scope.new(@tenant_admin, BulkImport.all).resolve
    property_admin_scope = BulkImportPolicy::Scope.new(@property_admin_p, BulkImport.all).resolve

    assert_includes tenant_scope, @bulk_import_p
    assert_includes tenant_scope, @bulk_import_q
    assert_includes property_admin_scope, @bulk_import_p
    refute_includes property_admin_scope, @bulk_import_q
  end
end
