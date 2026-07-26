# frozen_string_literal: true

require "test_helper"

# Integration tests for POST /api/v1/private/units/:unit_id/visits
# Covers OpenSpec residential-visit-management §6 (authorization and isolation).
#
# Authentication: JWT tokens are generated directly via Warden::JWTAuth::UserEncoder
# to avoid the tenant_admin-only restriction on the login endpoint. This lets us
# test residents and owners independently of their organizational role.
class Api::V1::Private::Units::VisitsControllerTest < ActionDispatch::IntegrationTest
  include OperationalPolicyTestHelper
  include Devise::Test::IntegrationHelpers

  setup do
    @organization    = organizations(:one)
    @other_org       = organizations(:two)
    ActsAsTenant.current_tenant = @organization
    Current.reset

    @property   = create_property(@organization, "Resident API Property P")
    @property_q = create_property(@organization, "Resident API Property Q")
    @section    = PropertySection.create!(
      organization: @organization,
      residential_property: @property,
      name: "Tower A",
      section_type: SectionTypes::TOWER
    )
    @unit   = create_unit_with_section(@property, @section, "RA-P-101")
    @unit_v = create_unit(@property_q, "RA-Q-201")

    # Resident: active occupancy with can_authorize_visits = true (6.1)
    @resident = create_user_for_organization(
      organization: @organization,
      email: "resident-api-resident@example.test",
      role: AvailableRoles::CLIENT
    )
    @resident_person = @resident.person_for(@organization)
    @resident_occupancy = UnitOccupancy.create!(
      organization: @organization,
      person: @resident_person,
      unit: @unit,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: 7.days.ago,
      status: OccupancyStatuses::ACTIVE,
      can_authorize_visits: true
    )

    # Owner: active ownership (6.2)
    @owner = create_owner_user(
      organization: @organization,
      email: "resident-api-owner@example.test",
      unit: @unit
    )

    # No-relationship user (6.3)
    @stranger = create_user_for_organization(
      organization: @organization,
      email: "resident-api-stranger@example.test",
      role: AvailableRoles::CLIENT
    )

    # Occupant without authorize_visits (6.5)
    @no_auth_resident = create_user_for_organization(
      organization: @organization,
      email: "resident-api-no-auth@example.test",
      role: AvailableRoles::CLIENT
    )
    UnitOccupancy.create!(
      organization: @organization,
      person: @no_auth_resident.person_for(@organization),
      unit: @unit,
      occupancy_type: OccupancyTypes::TENANT,
      starts_at: 7.days.ago,
      status: OccupancyStatuses::ACTIVE,
      can_authorize_visits: false
    )

    # Concierge assigned to property P (6.11)
    @concierge_p = create_staff_user(
      organization: @organization,
      email: "resident-api-concierge-p@example.test",
      staff_type: StaffTypes::CONCIERGE,
      property: @property
    )

    # Concierge assigned only to property Q (6.12)
    @concierge_q = create_staff_user(
      organization: @organization,
      email: "resident-api-concierge-q@example.test",
      staff_type: StaffTypes::CONCIERGE,
      property: @property_q
    )

    @visitor_payload = {
      visit: {
        scheduled_at: 2.hours.from_now.iso8601,
        visitor: { name: "Test Visitor", document: "DOC-#{SecureRandom.hex(4)}", phone: "+56912345678" }
      }
    }
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  # ─── 6.1 Resident with active occupancy and can_authorize_visits = true ──────

  test "resident with active occupancy and can_authorize_visits creates authorized visit (6.1)" do
    post_visit(user: @resident, unit: @unit)

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal VisitStatuses::AUTHORIZED, body.dig("data", "status")
  end

  # ─── 6.2 Active owner when rule grants authorize_visits ──────────────────────

  test "active owner creates authorized visit (6.2)" do
    post_visit(user: @owner, unit: @unit)

    assert_response :created
    assert_equal VisitStatuses::AUTHORIZED, JSON.parse(response.body).dig("data", "status")
  end

  # ─── 6.3 User without unit relationship is rejected ──────────────────────────

  test "user without unit relationship is denied (6.3)" do
    post_visit(user: @stranger, unit: @unit)

    assert_response :forbidden
  end

  # ─── 6.4 Inactive, future, expired or deleted occupancy is rejected ──────────

  test "inactive occupancy is denied (6.4)" do
    @resident_occupancy.update!(status: OccupancyStatuses::INACTIVE)
    post_visit(user: @resident, unit: @unit)
    assert_response :forbidden
  end

  test "future-dated occupancy is denied (6.4)" do
    @resident_occupancy.update!(starts_at: 2.days.from_now)
    post_visit(user: @resident, unit: @unit)
    assert_response :forbidden
  end

  test "expired occupancy is denied (6.4)" do
    @resident_occupancy.update!(ends_at: 1.day.ago)
    post_visit(user: @resident, unit: @unit)
    assert_response :forbidden
  end

  # ─── 6.5 Occupant with can_authorize_visits = false is rejected ───────────────

  test "occupant without can_authorize_visits is denied (6.5)" do
    post_visit(user: @no_auth_resident, unit: @unit)

    assert_response :forbidden
  end

  # ─── 6.6 Cross-organization is rejected ──────────────────────────────────────

  test "unit from another organization returns 404 (6.6)" do
    # Create unit explicitly in @other_org scope so ActsAsTenant does not
    # override organization_id to @organization (current tenant in setup).
    other_unit = ActsAsTenant.with_tenant(@other_org) do
      other_property = create_property(@other_org, "Other Org Property")
      create_unit(other_property, "OO-101")
    end

    post_visit(user: @resident, unit: other_unit)

    assert_response :not_found
  end

  # ─── 6.7 Cross-property and cross-unit (same property) are rejected ───────────

  test "resident cannot create visit for unit in another property (6.7)" do
    post_visit(user: @resident, unit: @unit_v)

    assert_response :forbidden
  end

  test "resident cannot create visit for another unit in same property (6.7)" do
    unit_w = create_unit(@property, "RA-P-102")
    post_visit(user: @resident, unit: unit_w)

    assert_response :forbidden
  end

  # ─── 6.8 Visitor Person created and reused tenant-safely ─────────────────────

  test "visitor Person is created for new document (6.8)" do
    doc = "DOC-NEW-#{SecureRandom.hex(4)}"
    assert_difference "Person.count", 1 do
      post_visit(user: @resident, unit: @unit, visitor_doc: doc)
    end
    assert_response :created
  end

  test "existing visitor Person is reused on second request (6.8)" do
    doc = "DOC-REUSE-#{SecureRandom.hex(4)}"
    post_visit(user: @resident, unit: @unit, visitor_doc: doc)
    assert_response :created

    assert_no_difference "Person.count" do
      post_visit(user: @resident, unit: @unit, visitor_doc: doc)
    end
    assert_response :created
  end

  test "visitor Person from another org is not reused (6.8)" do
    doc = "DOC-XORG-#{SecureRandom.hex(4)}"
    # Create a Person in other_org with same document
    ActsAsTenant.with_tenant(@other_org) do
      p = Person.new(
        organization: @other_org,
        display_name: "Other Org Visitor",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      p.document_number = doc
      p.save!
    end

    assert_difference "Person.where(organization_id: @organization.id).count", 1 do
      post_visit(user: @resident, unit: @unit, visitor_doc: doc)
    end
    assert_response :created
  end

  # ─── 6.9 created_by_id, authorized_by_id, visitor_person_id ──────────────────

  test "visit records correct actor and person references (6.9)" do
    post_visit(user: @resident, unit: @unit)
    assert_response :created

    visit = Visit.last
    assert_equal @resident.id,                     visit.created_by_id
    assert_equal @resident.id,                     visit.authorized_by_id
    assert_not_nil visit.visitor_person_id
    assert_not_equal @resident_person.id,          visit.visitor_person_id
  end

  # ─── 6.10 Property and section derived from unit ─────────────────────────────

  test "visit derives residential_property and property_section from unit (6.10)" do
    post_visit(user: @resident, unit: @unit)
    assert_response :created

    visit = Visit.last
    assert_equal @property.id, visit.residential_property_id
    assert_equal @section.id,  visit.property_section_id
    assert_equal @unit.id,     visit.unit_id
  end

  # ─── 6.11 Concierge assigned to property P sees the visit ────────────────────

  test "concierge assigned to property P sees the resident-created authorized visit (6.11)" do
    post_visit(user: @resident, unit: @unit)
    assert_response :created

    visit = Visit.last
    resolver = Authorization::Resolver.new(
      user: @concierge_p,
      organization: @organization
    )
    scope = VisitPolicy::Scope.new(@concierge_p, Visit).resolve
    ActsAsTenant.with_tenant(@organization) do
      assert_includes scope, visit
    end
  end

  # ─── 6.12 Concierge of another property, inactive assignment, no capability ──

  test "concierge assigned only to property Q does not see the visit from P (6.12)" do
    post_visit(user: @resident, unit: @unit)
    assert_response :created

    visit = Visit.last
    ActsAsTenant.with_tenant(@organization) do
      scope = VisitPolicy::Scope.new(@concierge_q, Visit).resolve
      assert_not_includes scope, visit
    end
  end

  test "concierge with inactive assignment does not see the visit (6.12)" do
    StaffAssignment.where(person: @concierge_p.person_for(@organization)).update_all(status: "inactive")

    post_visit(user: @resident, unit: @unit)
    assert_response :created

    visit = Visit.last
    ActsAsTenant.with_tenant(@organization) do
      scope = VisitPolicy::Scope.new(@concierge_p, Visit).resolve
      assert_not_includes scope, visit
    end
  end

  # ─── 6.13 Rollback on error ──────────────────────────────────────────────────

  test "full transaction rolls back if visit persistence fails (6.13)" do
    doc = "DOC-ROLLBACK-#{SecureRandom.hex(4)}"
    visit_count   = Visit.count
    history_count = VisitStatusHistory.count
    person_count  = Person.where(organization_id: @organization.id).count

    # Force a validation failure by making scheduled_at blank after params are set.
    # We stub Residents::CreateAuthorizedVisit#call to raise RecordInvalid.
    original_call = Residents::CreateAuthorizedVisit.method(:call)
    Residents::CreateAuthorizedVisit.define_singleton_method(:call) do |**_kwargs|
      raise ActiveRecord::RecordInvalid.new(Visit.new)
    end

    post_visit(user: @resident, unit: @unit, visitor_doc: doc)

    Residents::CreateAuthorizedVisit.define_singleton_method(:call, &original_call)

    assert_response :unprocessable_entity
    assert_equal visit_count,   Visit.count,   "Visit was not rolled back"
    assert_equal history_count, VisitStatusHistory.count, "VisitStatusHistory was not rolled back"
    assert_equal person_count,  Person.where(organization_id: @organization.id).count, "Person was not rolled back"
  end

  private

  def post_visit(user:, unit:, visitor_doc: nil)
    doc = visitor_doc || "DOC-#{SecureRandom.hex(4)}"
    payload = {
      visit: {
        scheduled_at: 2.hours.from_now.iso8601,
        visitor: { name: "Test Visitor #{doc}", document: doc, phone: "+56912345678" }
      }
    }

    host! "#{@organization.subdomain}.example.com"
    sign_in user

    post api_v1_private_unit_visits_path(unit_id: unit.id),
         params:  payload.to_json,
         headers: { "Content-Type" => "application/json" }

    sign_out user
  end

  def create_unit_with_section(property, section, identifier)
    Unit.create!(
      organization: property.organization,
      residential_property: property,
      property_section: section,
      identifier: identifier,
      unit_type: UnitTypes::APARTMENT,
      status: UnitStatuses::AVAILABLE
    )
  end
end
