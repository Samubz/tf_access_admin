# frozen_string_literal: true

require "test_helper"

# Only revoke/resolve_conflict remain here — invite/create moved to
# Admin::PeopleController#create (send_invitation checkbox) and #invite
# (existing person row action), since the standalone onboarding-requests
# screens were retired in favor of the People index/form.
class Admin::OnboardingRequestsControllerTest < ActionDispatch::IntegrationTest
  include InertiaTestHelper
  include ActionMailer::TestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    @admin = create_user_for_organization(
      organization: @organization, email: "onb-admin@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    @client = create_user_for_organization(
      organization: @organization, email: "onb-client@example.test", role: AvailableRoles::CLIENT
    )
  end

  teardown { ActsAsTenant.current_tenant = nil }

  test "revoke audits the actor with previous and new status" do
    sign_in_as(@admin)
    requester = @admin.person_for(@organization)
    person = create_person!(display_name: "Revocable")
    onboarding_request = OnboardingRequest.create!(
      organization: @organization, person: person, requested_by_person: requester,
      requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP,
      status: OnboardingRequest::STATUS_PENDING, expires_at: 7.days.from_now
    )

    post revoke_admin_onboarding_request_path(onboarding_request)

    onboarding_request.reload
    assert_equal OnboardingRequest::STATUS_REVOKED, onboarding_request.status
    assert_redirected_to admin_people_path

    audit = onboarding_request.audits.last
    assert_equal @admin, audit.user
    assert_equal [ OnboardingRequest::STATUS_PENDING, OnboardingRequest::STATUS_REVOKED ], audit.audited_changes["status"]
  end

  test "a manager other than the issuer can revoke a pending request" do
    issuer = create_user_for_organization(
      organization: @organization, email: "other-manager@example.test", role: AvailableRoles::TENANT_ADMIN
    )
    person = create_person!(display_name: "Revocable By Other")
    onboarding_request = OnboardingRequest.create!(
      organization: @organization, person: person,
      requested_by_person: issuer.person_for(@organization),
      requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP,
      status: OnboardingRequest::STATUS_PENDING, expires_at: 7.days.from_now
    )

    sign_in_as(@admin)
    post revoke_admin_onboarding_request_path(onboarding_request)

    assert_equal OnboardingRequest::STATUS_REVOKED, onboarding_request.reload.status
  end

  test "a non-manager cannot revoke a pending request" do
    person = create_person!(display_name: "Not Revocable")
    onboarding_request = OnboardingRequest.create!(
      organization: @organization, person: person,
      requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP,
      status: OnboardingRequest::STATUS_PENDING, expires_at: 7.days.from_now
    )

    sign_in_as(@client)
    post revoke_admin_onboarding_request_path(onboarding_request)

    assert_equal OnboardingRequest::STATUS_PENDING, onboarding_request.reload.status
  end

  private

  def create_person!(display_name:, document_number: nil)
    person = Person.new(
      organization: @organization, display_name: display_name,
      person_type: PersonTypes::NATURAL, status: PersonStatuses::ACTIVE
    )
    person.document_number = document_number if document_number
    person.save!
    person
  end

  def sign_in_as(user)
    host! "#{@organization.subdomain}.example.com"
    post user_session_path, params: { user: { email: user.email, password: "Password1@" } }
  end
end
