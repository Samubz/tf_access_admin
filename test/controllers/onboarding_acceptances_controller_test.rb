# frozen_string_literal: true

require "test_helper"

class OnboardingAcceptancesControllerTest < ActionDispatch::IntegrationTest
  include InertiaTestHelper

  setup do
    @organization = organizations(:one)
    host! "#{@organization.subdomain}.example.com"
    @result = ActsAsTenant.with_tenant(@organization) do
      Accounts::InvitePerson.call(
        organization: @organization,
        email: "accept-me@example.test",
        first_name: "Accept",
        last_name: "Me",
        document_number: "61.616.161-6"
      )
    end
  end

  teardown { ActsAsTenant.current_tenant = nil }

  test "show renders the neutral acceptance page" do
    inertia_get onboarding_acceptance_path(@result.token)

    assert_response :success
    assert_equal "onboarding/accept", inertia_component
    assert_equal @organization.name, inertia_props["organization_name"]
    assert inertia_props["needs_account"]
  end

  test "show for an existing account does not request password fields" do
    result = invite_existing_holder

    inertia_get onboarding_acceptance_path(result.token)

    assert_response :success
    assert_equal "onboarding/accept", inertia_component
    assert_equal false, inertia_props["needs_account"]
  end

  test "show for a legacy existing account invitation without user_id does not request password fields" do
    result = invite_existing_holder(attach_user: false)

    inertia_get onboarding_acceptance_path(result.token)

    assert_response :success
    assert_equal "onboarding/accept", inertia_component
    assert_equal false, inertia_props["needs_account"]
  end

  test "create accepts an existing account invitation without a password" do
    result = invite_existing_holder

    post onboarding_acceptance_path(result.token), params: {}

    assert_response :conflict
    assert_equal new_user_session_path, response.headers["X-Inertia-Location"]
    assert result.person.reload.user_id.present?
    assert_equal OrganizationMembership::STATUS_ACTIVE, result.person.organization_membership.status
  end

  test "create accepts a legacy existing account invitation without a password" do
    result = invite_existing_holder(attach_user: false)

    post onboarding_acceptance_path(result.token), params: {}

    assert_response :conflict
    assert_equal new_user_session_path, response.headers["X-Inertia-Location"]
    assert result.person.reload.user_id.present?
    assert_equal OrganizationMembership::STATUS_ACTIVE, result.person.organization_membership.status
  end

  test "show with an invalid token renders invalid" do
    inertia_get onboarding_acceptance_path("bogus-token")
    assert_response :unprocessable_entity
    assert_equal "onboarding/invalid", inertia_component
  end

  test "create accepts the invitation and creates a confirmed account" do
    post onboarding_acceptance_path(@result.token), params: { password: "Password1@" }

    # A plain redirect here would make the Inertia client follow the 302 via
    # fetch and mount the resulting Devise HTML inside its error dialog
    # (useDialogForErrorModal) instead of navigating — inertia_location's 409 +
    # X-Inertia-Location is the correct way to hand off to a non-Inertia page.
    assert_response :conflict
    assert_equal new_user_session_path, response.headers["X-Inertia-Location"]
    assert_equal I18n.t("onboarding.accept.success"), flash[:notice]

    person = @result.person.reload
    assert person.user_id.present?
    assert person.user.confirmed?
    assert_equal OrganizationMembership::STATUS_ACTIVE, person.organization_membership.status
  end

  test "create without a password redirects back with a renderable base error" do
    post onboarding_acceptance_path(@result.token), params: {}

    assert_redirected_to onboarding_acceptance_path(@result.token)

    inertia_get onboarding_acceptance_path(@result.token)
    base_error = inertia_props["errors"]&.fetch("base", nil)&.first
    assert base_error.present?
    refute_match(/translation missing/, base_error)
  end

  private

  def invite_existing_holder(attach_user: true)
    user = ActsAsTenant.without_tenant do
      User.create!(
        email: "existing-holder@example.test",
        password: "Password1@",
        password_confirmation: "Password1@",
        name: "Existing Holder",
        dni: SecureRandom.hex(4),
        language: Languages::ES,
        confirmed_at: Time.current
      )
    end
    person = Person.create!(
      organization: @organization,
      display_name: "Existing Holder",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    person.contact_email = user.email
    person.save!

    return Accounts::InvitePerson.call_for_person(person: person) if attach_user

    raw_token = SecureRandom.urlsafe_base64(32)
    request = OnboardingRequest.create!(
      organization: @organization,
      person: person,
      requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP,
      status: OnboardingRequest::STATUS_PENDING,
      token_digest: Accounts::InvitePerson.token_digest(raw_token),
      expires_at: 7.days.from_now
    )
    Accounts::InvitePerson::Result.new(onboarding_request: request, token: raw_token, person: person)
  end
end
