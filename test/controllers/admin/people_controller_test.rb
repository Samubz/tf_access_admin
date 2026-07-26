# frozen_string_literal: true

require "test_helper"

class Admin::PeopleControllerTest < ActionDispatch::IntegrationTest
  include InertiaTestHelper
  include ActionMailer::TestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization

    @property = ResidentialProperty.create!(
      organization: @organization,
      name: "People Show Property",
      property_type: PropertyTypes::BUILDING,
      status: "active",
      country: "Chile",
      timezone: "America/Santiago"
    )
    @section = PropertySection.create!(
      organization: @organization,
      residential_property: @property,
      name: "Level 1",
      section_type: "floor"
    )
    @unit = Unit.create!(
      organization: @organization,
      residential_property: @property,
      property_section: @section,
      identifier: "PEO-101",
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
    @person = Person.create!(
      organization: @organization,
      display_name: "People Show Person",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE,
      document_number: "12.345.678-9"
    )
    @ownership = UnitOwnership.create!(
      organization: @organization,
      unit: @unit,
      person: @person,
      ownership_percentage: 100,
      starts_at: Date.current,
      status: UnitOwnership::STATUS_ACTIVE
    )
    @occupancy = UnitOccupancy.create!(
      organization: @organization,
      unit: @unit,
      person: @person,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: Time.current,
      status: OccupancyStatuses::ACTIVE
    )

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "people-show-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @non_admin = create_user_for_organization(
      organization: @organization,
      email: "people-show-client@example.test",
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

  test "index includes contextual roles for each person" do
    sign_in_as(@tenant_admin)

    inertia_get admin_people_path

    assert_response :success
    assert_equal "admin/people/index", inertia_component

    person_row = inertia_props["people"].find { |row| row["id"] == @person.id }
    assert_includes person_row["contextual_roles"], People::ContextualRoles::OWNER
    assert_includes person_row["contextual_roles"], People::ContextualRoles::RESIDENT
  end

  test "show route renders unified profile props" do
    sign_in_as(@tenant_admin)

    inertia_get admin_person_path(@person)

    assert_response :success
    assert_equal "admin/people/show", inertia_component
    props = inertia_props

    assert_equal @person.id, props["person"]["id"]
    assert_equal "People Show Person", props["person"]["display_name"]
    assert_includes props["contextual_roles"], People::ContextualRoles::OWNER
    assert_includes props["contextual_roles"], People::ContextualRoles::RESIDENT
    assert_equal 1, props["summary"]["active_ownerships_count"]
    assert_equal 1, props["summary"]["active_occupancies_count"]
    assert_equal 0, props["summary"]["visits_count"]
    assert_equal 0, props["summary"]["staff_assignments_count"]
    assert_equal [], props["staff_assignments"]
    assert_equal [], props["visits"]
    assert props["permissions"]["view"]
    assert props["permissions"]["edit"]
    assert props["permissions"]["update"]
    assert props["permissions"]["destroy"]
    assert_equal 1, props["ownerships"].size
    assert_equal "People Show Property", props["ownerships"].first["residential_property_name"]
    assert_equal "Level 1", props["ownerships"].first["property_section_name"]
    assert_equal "PEO-101", props["ownerships"].first["unit_identifier"]
    assert_equal 1, props["occupancies"].size
    assert props["ownerships_pagination"]["total_count"].present?
    assert props["occupancies_pagination"]["total_count"].present?
    assert props["change_history"].is_a?(Array)
  end

  test "show change history is ordered from newest to oldest" do
    sign_in_as(@tenant_admin)

    travel_to 2.days.ago do
      Person.without_auditing do
        @person.update!(display_name: "People Show Person Older")
      end
      @person.update!(display_name: "People Show Person Older Audited")
    end

    travel_to 1.day.ago do
      @person.update!(display_name: "People Show Person Newer")
    end

    inertia_get admin_person_path(@person)

    assert_response :success
    timestamps = inertia_props["change_history"].map { |entry| Time.zone.parse(entry["occurred_at"]) }
    assert_operator timestamps.size, :>=, 2
    assert_equal timestamps.sort.reverse, timestamps
  end

  test "show denies access for non admin user" do
    sign_in_as(@non_admin)

    inertia_get admin_person_path(@person)

    assert_response :redirect
  end

  test "show does not expose person from another organization" do
    sign_in_as(@tenant_admin)

    inertia_get admin_person_path(@other_org_person)

    assert_redirected_to admin_people_url(host: "#{@organization.subdomain}.example.com")
  end

  test "show exposes real staff_assignments for person with active assignment" do
    assignment = StaffAssignment.create!(
      organization: @organization,
      person: @person,
      residential_property: @property,
      staff_type: StaffTypes::MANAGER,
      status: StaffAssignment::STATUS_ACTIVE,
      starts_at: Date.current
    )

    sign_in_as(@tenant_admin)
    inertia_get admin_person_path(@person)

    assert_response :success
    staff = inertia_props["staff_assignments"]
    assert_equal 1, staff.size
    row = staff.first
    assert_equal assignment.id, row["id"]
    assert_equal "People Show Property", row["residential_property_name"]
    assert_equal Authorization::StaffRoleMapper::PROPERTY_ADMIN, row["role"]
    assert_equal StaffAssignment::STATUS_ACTIVE, row["status"]
  end

  test "show staff_assignments excludes inactive assignments" do
    StaffAssignment.create!(
      organization: @organization,
      person: @person,
      residential_property: @property,
      staff_type: StaffTypes::CONCIERGE,
      status: StaffAssignment::STATUS_INACTIVE,
      starts_at: Date.current
    )

    sign_in_as(@tenant_admin)
    inertia_get admin_person_path(@person)

    assert_response :success
    assert_equal [], inertia_props["staff_assignments"]
  end

  test "show staff_assignments excludes expired assignments" do
    StaffAssignment.create!(
      organization: @organization,
      person: @person,
      residential_property: @property,
      staff_type: StaffTypes::MANAGER,
      status: StaffAssignment::STATUS_ACTIVE,
      starts_at: 30.days.ago.to_date,
      ends_at: Date.yesterday
    )

    sign_in_as(@tenant_admin)
    inertia_get admin_person_path(@person)

    assert_response :success
    assert_equal [], inertia_props["staff_assignments"]
  end

  test "show includes staff contextual role for person with active assignment" do
    StaffAssignment.create!(
      organization: @organization,
      person: @person,
      residential_property: @property,
      staff_type: StaffTypes::CONCIERGE,
      status: StaffAssignment::STATUS_ACTIVE,
      starts_at: Date.current
    )

    sign_in_as(@tenant_admin)
    inertia_get admin_person_path(@person)

    assert_response :success
    assert_includes inertia_props["contextual_roles"], People::ContextualRoles::CONCIERGE
  end

  test "show serializes multiple ownership rows with preloaded property context" do
    2.times do |index|
      unit = Unit.create!(
        organization: @organization,
        residential_property: @property,
        property_section: @section,
        identifier: "PEO-10#{index + 2}",
        unit_type: UnitTypes::APARTMENT,
        status: UnitStatuses::AVAILABLE
      )
      UnitOwnership.create!(
        organization: @organization,
        unit: unit,
        person: @person,
        ownership_percentage: 10,
        starts_at: Date.current,
        status: UnitOwnership::STATUS_ACTIVE
      )
    end

    sign_in_as(@tenant_admin)
    inertia_get admin_person_path(@person)

    assert_response :success
    assert_equal 3, inertia_props["ownerships"].size
    assert inertia_props["ownerships"].all? { |row| row["residential_property_name"].present? }
    assert inertia_props["ownerships"].all? { |row| row["unit_identifier"].present? }
  end

  test "index exposes invitation_status per person" do
    sign_in_as(@tenant_admin)

    inertia_get admin_people_path

    person_row = inertia_props["people"].find { |row| row["id"] == @person.id }
    assert_equal "not_invited", person_row["invitation_status"]
  end

  test "index reports pending invitation status" do
    OnboardingRequest.create!(
      organization: @organization, person: @person,
      requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP,
      status: OnboardingRequest::STATUS_PENDING, expires_at: 7.days.from_now
    )

    sign_in_as(@tenant_admin)
    inertia_get admin_people_path

    person_row = inertia_props["people"].find { |row| row["id"] == @person.id }
    assert_equal "pending", person_row["invitation_status"]
  end

  test "create with send_invitation sends an invitation for the new person" do
    sign_in_as(@tenant_admin)

    assert_enqueued_emails 1 do
      post admin_people_path, params: {
        person: {
          first_name: "Invite", last_name: "Me", document_number: "22.222.222-2",
          email: "invite-on-create@example.test", send_invitation: true
        }
      }
    end

    person = Person.find_by(document_number_digest: Person.document_digest("22222222-2"))
    assert person.present?
    assert_equal 1, person.onboarding_requests.pending.count
  end

  test "create without send_invitation does not send an invitation" do
    sign_in_as(@tenant_admin)

    assert_no_enqueued_emails do
      post admin_people_path, params: {
        person: { first_name: "No", last_name: "Invite", email: "no-invite-on-create@example.test" }
      }
    end
  end

  test "invite sends an invitation to an existing not-yet-invited person" do
    sign_in_as(@tenant_admin)
    @person.contact_email = "invite-existing@example.test"
    @person.save!

    assert_enqueued_emails 1 do
      post invite_admin_person_path(@person)
    end

    assert_redirected_to admin_people_path
    assert_equal 1, @person.reload.onboarding_requests.pending.count
  end

  test "invite audits the actor and does not leak the token or document" do
    sign_in_as(@tenant_admin)
    @person.contact_email = "invite-audited@example.test"
    @person.save!

    post invite_admin_person_path(@person)

    onboarding_request = @person.reload.onboarding_requests.pending.last
    audit = onboarding_request.audits.last

    assert_equal @tenant_admin, audit.user
    assert_equal "create", audit.action
    assert_equal @organization.id, audit.organization_id
    assert_equal OnboardingRequest::STATUS_PENDING, audit.audited_changes["status"]
    refute audit.audited_changes.key?("token_digest")
    refute audit.audited_changes.to_s.include?(@person.document_number)
  end

  test "invite on an already-invited person redirects with a renderable error and sends no email" do
    OnboardingRequest.create!(
      organization: @organization, person: @person,
      requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP,
      status: OnboardingRequest::STATUS_PENDING, expires_at: 7.days.from_now
    )

    sign_in_as(@tenant_admin)

    assert_no_enqueued_emails do
      post invite_admin_person_path(@person)
    end

    assert_redirected_to admin_people_path
    error_text = I18n.t("frontend.admin.people.errors.already_invited")
    refute_match(/translation missing/, error_text)
  end

  test "invite on a person without an email redirects with a renderable error and sends no email" do
    sign_in_as(@tenant_admin)
    assert_nil @person.contact_email

    assert_no_enqueued_emails do
      post invite_admin_person_path(@person)
    end

    assert_redirected_to admin_people_path
    assert_equal 0, @person.reload.onboarding_requests.count
    error_text = I18n.t("frontend.admin.people.errors.missing_email")
    refute_match(/translation missing/, error_text)
  end

  test "non-manager cannot invite a person" do
    sign_in_as(@non_admin)

    assert_no_enqueued_emails do
      post invite_admin_person_path(@person)
    end
  end

  private

  def sign_in_as(user)
    host! "#{@organization.subdomain}.example.com"
    post user_session_path, params: { user: { email: user.email, password: "Password1@" } }
  end
end
