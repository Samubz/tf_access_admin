# frozen_string_literal: true

require "test_helper"

class PersonPolicyTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization

    @person = Person.create!(
      organization: @organization,
      display_name: "Policy Person",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "tenant-admin-person-policy@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )

    @non_admin = create_user_for_organization(
      organization: @organization,
      email: "client-person-policy@example.test",
      role: AvailableRoles::CLIENT
    )

    @other_org_person = ActsAsTenant.with_tenant(@other_organization) do
      Person.create!(
        organization: @other_organization,
        display_name: "Other Org Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
    end
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "tenant admin can show person in current organization" do
    assert PersonPolicy.new(@tenant_admin, @person).show?
  end

  test "non admin cannot show person" do
    refute PersonPolicy.new(@non_admin, @person).show?
  end

  test "tenant admin cannot show person from another organization" do
    refute PersonPolicy.new(@tenant_admin, @other_org_person).show?
  end
end
