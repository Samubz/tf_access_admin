# frozen_string_literal: true

require "test_helper"

class AuthorizationPropertyScopeTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization

    @property_a = create_property(@organization, "Scope Property A")
    @property_b = create_property(@organization, "Scope Property B")
    @other_org_property = ActsAsTenant.with_tenant(@other_organization) do
      create_property(@other_organization, "Scope Other Org Property")
    end
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "tenant_admin property scope includes all organization properties" do
    user = create_user_for_organization(
      organization: @organization,
      email: "tenant-admin-scope@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    scope = property_scope_for(user)

    assert_includes scope.accessible_property_ids, @property_a.id
    assert_includes scope.accessible_property_ids, @property_b.id
    refute_includes scope.accessible_property_ids, @other_org_property.id
  end

  test "property_admin property scope includes only assigned properties" do
    user = create_staff_user(
      email: "property-admin-scope@example.test",
      staff_type: StaffTypes::MANAGER,
      property: @property_a
    )
    scope = property_scope_for(user)

    assert_equal [ @property_a.id ], scope.accessible_property_ids.sort
    refute_includes scope.accessible_property_ids, @property_b.id
    refute_includes scope.accessible_property_ids, @other_org_property.id
  end

  test "owner property scope includes properties for active owned units" do
    user = create_user_for_organization(
      organization: @organization,
      email: "owner-scope@example.test",
      role: AvailableRoles::CLIENT
    )
    unit = create_unit(@property_b, "OWNER-SCOPE-101")
    create_ownership(person: user.person_for(@organization), unit: unit)

    scope = property_scope_for(user)

    assert_includes scope.accessible_property_ids, @property_b.id
    refute_includes scope.accessible_property_ids, @other_org_property.id
  end

  test "property scope never returns properties from another organization" do
    user = create_user_for_organization(
      organization: @organization,
      email: "cross-org-scope@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    scope = property_scope_for(user)

    refute_includes scope.accessible_property_ids, @other_org_property.id
  end

  private

  def property_scope_for(user)
    resolver = Authorization::Resolver.new(user: user, organization: @organization)
    Authorization::PropertyScope.new(resolver)
  end

  def create_property(organization, name)
    ResidentialProperty.create!(
      organization: organization,
      name: name,
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
  end

  def create_unit(property, identifier)
    Unit.create!(
      organization: property.organization,
      residential_property: property,
      identifier: identifier,
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
  end

  def create_staff_user(email:, staff_type:, property:)
    user = create_user_for_organization(
      organization: @organization,
      email: email,
      role: AvailableRoles::CLIENT
    )

    StaffAssignment.create!(
      organization: @organization,
      person: user.person_for(@organization),
      residential_property: property,
      staff_type: staff_type,
      status: "active",
      starts_at: Date.current
    )

    user
  end

  def create_ownership(person:, unit:)
    UnitOwnership.create!(
      organization: @organization,
      person: person,
      unit: unit,
      ownership_percentage: 100,
      starts_at: Date.current,
      status: UnitOwnership::STATUS_ACTIVE
    )
  end
end
