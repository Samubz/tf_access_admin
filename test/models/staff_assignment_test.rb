# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_assignments
#
#  id                      :uuid             not null, primary key
#  confirmation_state      :string           default("confirmed"), not null
#  confirmed_at            :datetime
#  ends_at                 :date
#  metadata                :jsonb            not null
#  staff_type              :string           not null
#  starts_at               :date
#  status                  :string           default("active"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  organization_id         :uuid             not null
#  person_id               :uuid             not null
#  residential_property_id :uuid             not null
#
# Indexes
#
#  idx_on_organization_id_person_id_status_36b5c5bfed   (organization_id,person_id,status)
#  index_staff_assignments_on_confirmation_state        (confirmation_state)
#  index_staff_assignments_on_metadata                  (metadata) USING gin
#  index_staff_assignments_on_org_property_type_status  (organization_id,residential_property_id,staff_type,status)
#  index_staff_assignments_on_organization_id           (organization_id)
#  index_staff_assignments_on_person_id                 (person_id)
#  index_staff_assignments_on_residential_property_id   (residential_property_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (person_id => people.id)
#  fk_rails_...  (residential_property_id => residential_properties.id)
#
require "test_helper"

class StaffAssignmentTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization

    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "Test Property",
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

    @person = create_person_in_org(@organization)
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  # ---------------------------------------------------------------------------
  # 5.1 — Active scopes
  # ---------------------------------------------------------------------------

  test "active scope returns assignments with active status" do
    active = create_assignment(@person, @property, staff_type: StaffTypes::CONCIERGE, status: StaffAssignment::STATUS_ACTIVE)
    inactive = create_assignment(@person, @property, staff_type: StaffTypes::CLEANING, status: StaffAssignment::STATUS_INACTIVE)

    result = StaffAssignment.active.to_a

    assert_includes result, active
    refute_includes result, inactive
  end

  test "currently_active scope excludes expired assignments" do
    expired = create_assignment(
      @person, @property,
      staff_type: StaffTypes::CONCIERGE,
      starts_at: 30.days.ago.to_date,
      ends_at: Date.yesterday
    )

    result = StaffAssignment.currently_active.to_a

    refute_includes result, expired
  end

  test "currently_active scope excludes future assignments" do
    future_assignment = create_assignment(
      @person, @property,
      staff_type: StaffTypes::MANAGER,
      starts_at: Date.tomorrow,
      ends_at: nil
    )

    result = StaffAssignment.currently_active.to_a

    refute_includes result, future_assignment
  end

  test "currently_active scope includes assignment with open-ended validity" do
    assignment = create_assignment(
      @person, @property,
      staff_type: StaffTypes::CONCIERGE,
      starts_at: Date.current,
      ends_at: nil
    )

    result = StaffAssignment.currently_active.to_a

    assert_includes result, assignment
  end

  test "currently_active scope excludes inactive assignment regardless of dates" do
    assignment = create_assignment(
      @person, @property,
      staff_type: StaffTypes::MANAGER,
      status: StaffAssignment::STATUS_INACTIVE,
      starts_at: Date.current,
      ends_at: nil
    )

    result = StaffAssignment.currently_active.to_a

    refute_includes result, assignment
  end

  test "for_property scope filters by property" do
    other_person = create_person_in_org(@organization, email: "p2@example.test")
    other_property = ResidentialProperty.create!(
      organization: @organization,
      name: "Other Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )

    assignment_a = create_assignment(@person, @property, staff_type: StaffTypes::CONCIERGE)
    assignment_b = create_assignment(other_person, other_property, staff_type: StaffTypes::CLEANING)

    result = StaffAssignment.for_property(@property).to_a

    assert_includes result, assignment_a
    refute_includes result, assignment_b
  end

  test "for_person scope filters by person" do
    other_person = create_person_in_org(@organization, email: "p3@example.test")
    assignment_a = create_assignment(@person, @property, staff_type: StaffTypes::MANAGER)
    assignment_b = create_assignment(other_person, @property, staff_type: StaffTypes::SECURITY)

    result = StaffAssignment.for_person(@person).to_a

    assert_includes result, assignment_a
    refute_includes result, assignment_b
  end

  # ---------------------------------------------------------------------------
  # 5.4 — Staff type normalization via StaffRoleMapper
  # ---------------------------------------------------------------------------

  test "manager normalizes to property_admin" do
    assert_equal Authorization::StaffRoleMapper::PROPERTY_ADMIN,
                 Authorization::StaffRoleMapper.operational_role_for(StaffTypes::MANAGER)
  end

  test "property_admin alias normalizes to property_admin" do
    assert_equal Authorization::StaffRoleMapper::PROPERTY_ADMIN,
                 Authorization::StaffRoleMapper.operational_role_for(StaffTypes::PROPERTY_ADMIN)
  end

  test "concierge normalizes to concierge" do
    assert_equal Authorization::StaffRoleMapper::CONCIERGE,
                 Authorization::StaffRoleMapper.operational_role_for(StaffTypes::CONCIERGE)
  end

  test "security normalizes to concierge" do
    assert_equal Authorization::StaffRoleMapper::CONCIERGE,
                 Authorization::StaffRoleMapper.operational_role_for(StaffTypes::SECURITY)
  end

  test "cleaning normalizes to cleaning_staff" do
    assert_equal Authorization::StaffRoleMapper::CLEANING_STAFF,
                 Authorization::StaffRoleMapper.operational_role_for(StaffTypes::CLEANING)
  end

  test "cleaning_staff alias normalizes to cleaning_staff" do
    assert_equal Authorization::StaffRoleMapper::CLEANING_STAFF,
                 Authorization::StaffRoleMapper.operational_role_for(StaffTypes::CLEANING_STAFF)
  end

  test "maintenance normalizes to internal_staff" do
    assert_equal Authorization::StaffRoleMapper::INTERNAL_STAFF,
                 Authorization::StaffRoleMapper.operational_role_for(StaffTypes::MAINTENANCE)
  end

  test "other normalizes to internal_staff" do
    assert_equal Authorization::StaffRoleMapper::INTERNAL_STAFF,
                 Authorization::StaffRoleMapper.operational_role_for(StaffTypes::OTHER)
  end

  test "internal_staff alias normalizes to internal_staff" do
    assert_equal Authorization::StaffRoleMapper::INTERNAL_STAFF,
                 Authorization::StaffRoleMapper.operational_role_for(StaffTypes::INTERNAL_STAFF)
  end

  # ---------------------------------------------------------------------------
  # 5.6 — Integration: staff type → resolver capabilities
  # ---------------------------------------------------------------------------

  test "property_admin (manager type) gets administrative capabilities on assigned property" do
    user = create_staff_user(staff_type: StaffTypes::MANAGER, property: @property)
    resolver = resolver_for(user, property: @property)

    assert resolver.allowed?(:manage_units)
    assert resolver.allowed?(:manage_ownerships)
    assert resolver.allowed?(:manage_occupancies)
    assert resolver.allowed?(:manage_people)
    assert resolver.allowed?(:manage_staff_assignments)
    assert resolver.allowed?(:manage_visits)
  end

  test "property_admin does not get capabilities on another property" do
    other_property = ResidentialProperty.create!(
      organization: @organization,
      name: "Other Property for Test",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
    user = create_staff_user(staff_type: StaffTypes::MANAGER, property: @property)
    resolver = resolver_for(user, property: other_property)

    refute resolver.allowed?(:manage_units)
    refute resolver.allowed?(:manage_ownerships)
  end

  test "concierge gets visit access-control capabilities on assigned property" do
    user = create_staff_user(staff_type: StaffTypes::CONCIERGE, property: @property)
    resolver = resolver_for(user, property: @property)

    assert resolver.allowed?(:view_visits)
    assert resolver.allowed?(:register_visit_entry)
    assert resolver.allowed?(:register_visit_exit)
    assert resolver.allowed?(:view_minimal_access_control_data)
  end

  test "concierge does not get manage_people, manage_users, manage_ownerships, manage_occupancies" do
    user = create_staff_user(staff_type: StaffTypes::CONCIERGE, property: @property)
    resolver = resolver_for(user, property: @property)

    refute resolver.allowed?(:manage_people)
    refute resolver.allowed?(:manage_users)
    refute resolver.allowed?(:manage_ownerships)
    refute resolver.allowed?(:manage_occupancies)
  end

  test "cleaning_staff does not receive administrative permissions by default" do
    user = create_staff_user(staff_type: StaffTypes::CLEANING, property: @property)
    resolver = resolver_for(user, property: @property)

    refute resolver.allowed?(:manage_units)
    refute resolver.allowed?(:manage_people)
    refute resolver.allowed?(:manage_ownerships)
    refute resolver.allowed?(:view_visits)
  end

  test "internal_staff (maintenance type) does not receive administrative permissions by default" do
    user = create_staff_user(staff_type: StaffTypes::MAINTENANCE, property: @property)
    resolver = resolver_for(user, property: @property)

    refute resolver.allowed?(:manage_units)
    refute resolver.allowed?(:manage_people)
    refute resolver.allowed?(:manage_ownerships)
    refute resolver.allowed?(:view_visits)
  end

  test "inactive assignment does not grant capabilities" do
    user = create_staff_user(
      staff_type: StaffTypes::MANAGER,
      property: @property,
      status: StaffAssignment::STATUS_INACTIVE
    )
    resolver = resolver_for(user, property: @property)

    refute resolver.allowed?(:manage_units)
    refute resolver.allowed?(:manage_ownerships)
  end

  test "expired assignment does not grant capabilities" do
    user = create_staff_user(
      staff_type: StaffTypes::MANAGER,
      property: @property,
      starts_at: 30.days.ago.to_date,
      ends_at: Date.yesterday
    )
    resolver = resolver_for(user, property: @property)

    refute resolver.allowed?(:manage_units)
    refute resolver.allowed?(:manage_ownerships)
  end

  test "future assignment does not grant capabilities" do
    user = create_staff_user(
      staff_type: StaffTypes::CONCIERGE,
      property: @property,
      starts_at: Date.tomorrow,
      ends_at: nil
    )
    resolver = resolver_for(user, property: @property)

    refute resolver.allowed?(:view_visits)
    refute resolver.allowed?(:register_visit_entry)
  end

  # ---------------------------------------------------------------------------
  # 5.5 — Audit trail
  # ---------------------------------------------------------------------------

  test "creating a staff assignment generates an audit record" do
    assert_difference -> { Audited::Audit.count } do
      create_assignment(@person, @property, staff_type: StaffTypes::CONCIERGE)
    end
  end

  test "updating status on a staff assignment generates an audit record" do
    assignment = create_assignment(@person, @property, staff_type: StaffTypes::MANAGER)

    assert_difference -> { Audited::Audit.count } do
      assignment.update!(status: StaffAssignment::STATUS_INACTIVE)
    end
  end

  # ---------------------------------------------------------------------------
  # 5.7 — Date validations
  # ---------------------------------------------------------------------------

  test "ends_at before starts_at is invalid" do
    assignment = StaffAssignment.new(
      organization: @organization,
      person: @person,
      residential_property: @property,
      staff_type: StaffTypes::CONCIERGE,
      status: StaffAssignment::STATUS_ACTIVE,
      starts_at: Date.current,
      ends_at: Date.yesterday
    )

    refute assignment.valid?
    assert assignment.errors[:ends_at].any?
  end

  test "ends_at equal to starts_at is valid" do
    assignment = StaffAssignment.new(
      organization: @organization,
      person: @person,
      residential_property: @property,
      staff_type: StaffTypes::CONCIERGE,
      status: StaffAssignment::STATUS_ACTIVE,
      starts_at: Date.current,
      ends_at: Date.current
    )

    assert assignment.valid?
  end

  test "ends_at after starts_at is valid" do
    assignment = StaffAssignment.new(
      organization: @organization,
      person: @person,
      residential_property: @property,
      staff_type: StaffTypes::CLEANING,
      status: StaffAssignment::STATUS_ACTIVE,
      starts_at: Date.current,
      ends_at: Date.current + 30
    )

    assert assignment.valid?
  end

  test "status must be active or inactive" do
    assignment = StaffAssignment.new(
      organization: @organization,
      person: @person,
      residential_property: @property,
      staff_type: StaffTypes::MANAGER,
      status: "pending"
    )

    refute assignment.valid?
    assert assignment.errors[:status].any?
  end

  # ---------------------------------------------------------------------------
  # Operational roles are confirmable (normalize-user-identity-and-property-onboarding §16.2)
  # ---------------------------------------------------------------------------

  test "confirmation_state defaults to confirmed" do
    assignment = create_assignment(@person, @property, staff_type: StaffTypes::CONCIERGE)

    assert_equal StaffAssignment::CONFIRMATION_CONFIRMED, assignment.confirmation_state
    assert_predicate assignment, :confirmed?
  end

  test "confirmation_state must be pending or confirmed" do
    assignment = StaffAssignment.new(
      organization: @organization,
      person: @person,
      residential_property: @property,
      staff_type: StaffTypes::MANAGER,
      status: StaffAssignment::STATUS_ACTIVE,
      confirmation_state: "bogus"
    )

    refute assignment.valid?
    assert assignment.errors[:confirmation_state].any?
  end

  test "confirm! stamps confirmed_at and marks confirmed" do
    assignment = StaffAssignment.create!(
      organization: @organization,
      person: @person,
      residential_property: @property,
      staff_type: StaffTypes::CONCIERGE,
      status: StaffAssignment::STATUS_ACTIVE,
      confirmation_state: StaffAssignment::CONFIRMATION_PENDING
    )

    assert_nil assignment.confirmed_at
    refute_predicate assignment, :confirmed?

    assignment.confirm!

    assert_predicate assignment, :confirmed?
    assert_not_nil assignment.confirmed_at
  end

  test "confirmed and pending_confirmation scopes partition assignments" do
    pending = StaffAssignment.create!(
      organization: @organization,
      person: @person,
      residential_property: @property,
      staff_type: StaffTypes::CONCIERGE,
      status: StaffAssignment::STATUS_ACTIVE,
      confirmation_state: StaffAssignment::CONFIRMATION_PENDING
    )
    confirmed = create_assignment(
      create_person_in_org(@organization, email: "confirmed@example.test"),
      @property,
      staff_type: StaffTypes::CLEANING
    )

    assert_includes StaffAssignment.pending_confirmation.to_a, pending
    refute_includes StaffAssignment.pending_confirmation.to_a, confirmed
    assert_includes StaffAssignment.confirmed.to_a, confirmed
    refute_includes StaffAssignment.confirmed.to_a, pending
  end

  private

  def create_person_in_org(organization, email: "staff-test-person@example.test")
    ActsAsTenant.with_tenant(organization) do
      user = User.create!(
        email: email,
        password: "Password1@",
        password_confirmation: "Password1@",
        name: "Test Person",
        dni: SecureRandom.hex(4),
        language: Languages::ES,
        confirmed_at: Time.current
      )
      Accounts::ProvisionTenantIdentity.call(user: user, organization: organization)
      user.person_for(organization)
    end
  end

  def create_assignment(person, property, staff_type:, status: StaffAssignment::STATUS_ACTIVE, starts_at: Date.current, ends_at: nil)
    StaffAssignment.create!(
      organization: @organization,
      person: person,
      residential_property: property,
      staff_type: staff_type,
      status: status,
      starts_at: starts_at,
      ends_at: ends_at
    )
  end

  def create_staff_user(staff_type:, property:, status: StaffAssignment::STATUS_ACTIVE, starts_at: Date.current, ends_at: nil)
    email = "staff-#{SecureRandom.hex(4)}@example.test"
    ActsAsTenant.with_tenant(@organization) do
      user = User.create!(
        email: email,
        password: "Password1@",
        password_confirmation: "Password1@",
        name: "Staff User",
        dni: SecureRandom.hex(4),
        language: Languages::ES,
        confirmed_at: Time.current
      )
      Accounts::ProvisionTenantIdentity.call(user: user, organization: @organization)
      person = user.person_for(@organization)
      StaffAssignment.create!(
        organization: @organization,
        person: person,
        residential_property: property,
        staff_type: staff_type,
        status: status,
        starts_at: starts_at,
        ends_at: ends_at
      )
      user
    end
  end

  def resolver_for(user, property: nil, unit: nil)
    Authorization::Resolver.new(
      user: user,
      organization: @organization,
      property: property,
      unit: unit
    )
  end
end
