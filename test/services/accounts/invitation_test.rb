# frozen_string_literal: true

require "test_helper"

module Accounts
  class InvitationTest < ActiveSupport::TestCase
    setup do
      @organization = organizations(:one)
      @other_organization = organizations(:two)
      ActsAsTenant.current_tenant = @organization
    end

    teardown do
      ActsAsTenant.current_tenant = nil
      Current.reset
    end

    # --- InvitePerson -------------------------------------------------------

    test "invites a brand-new person and issues a pending request with a hashed token" do
      result = InvitePerson.call(
        organization: @organization,
        email: "newbie@example.test",
        first_name: "New",
        last_name: "Bie"
      )

      request = result.onboarding_request
      assert request.pending?
      assert_not_nil result.token
      assert_not_nil result.person
      # Only the digest is persisted, never the raw token.
      assert_equal InvitePerson.token_digest(result.token), request.token_digest
      refute_equal result.token, request.token_digest
    end

    test "references an existing account for incorporation" do
      user = create_bare_user!(email: "existing@example.test")

      result = InvitePerson.call(organization: @organization, email: "existing@example.test")

      assert_equal user.id, result.onboarding_request.user_id
      assert result.person.present?
    end

    test "call_for_person references an existing account by contact email" do
      user = create_bare_user!(email: "known-holder@example.test")
      person = create_person!(display_name: "Known Holder")
      person.contact_email = "known-holder@example.test"
      person.save!

      result = InvitePerson.call_for_person(person: person)

      assert_equal user.id, result.onboarding_request.user_id
    end

    test "records a conflict without a token" do
      create_org_user!(email: "taken@example.test")
      person_a = create_person!(display_name: "A", document_number: "88.888.888-8")
      person_a # matched by document; email belongs to the other account
      _unused = person_a

      result = InvitePerson.call(
        organization: @organization,
        email: "taken@example.test",
        document_number: "88888888-8"
      )

      assert result.conflict?
      assert_nil result.token
    end

    # --- AcceptInvitation (existing account, Flow C) ------------------------

    test "accepting with a valid token links the account and activates membership" do
      user = create_bare_user!(email: "incorporate@example.test")
      result = InvitePerson.call(organization: @organization, email: "incorporate@example.test")

      AcceptInvitation.call(token: result.token, organization: @organization)

      person = result.person.reload
      assert_equal user.id, person.user_id
      assert person.has_role?(AvailableRoles::CLIENT)
      assert_equal OrganizationMembership::STATUS_ACTIVE, person.organization_membership.status
    end

    test "accepting a legacy request without user_id uses the existing account by contact email" do
      user = create_bare_user!(email: "legacy-incorporate@example.test")
      person = create_person!(display_name: "Legacy Incorporate")
      person.contact_email = "legacy-incorporate@example.test"
      person.save!
      raw_token = SecureRandom.urlsafe_base64(32)
      request = OnboardingRequest.create!(
        organization: @organization,
        person: person,
        requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP,
        status: OnboardingRequest::STATUS_PENDING,
        token_digest: InvitePerson.token_digest(raw_token),
        expires_at: 7.days.from_now
      )

      AcceptInvitation.call(token: raw_token, organization: @organization)

      assert_equal user.id, person.reload.user_id
      assert request.reload.accepted?
      assert_equal OrganizationMembership::STATUS_ACTIVE, person.organization_membership.status
    end

    test "token is single-use" do
      create_bare_user!(email: "once@example.test")
      result = InvitePerson.call(organization: @organization, email: "once@example.test")

      AcceptInvitation.call(token: result.token, organization: @organization)

      assert_raises(AcceptInvitation::InvalidToken) do
        AcceptInvitation.call(token: result.token, organization: @organization)
      end
    end

    test "invalid token is rejected" do
      assert_raises(AcceptInvitation::InvalidToken) do
        AcceptInvitation.call(token: "not-a-real-token", organization: @organization)
      end
    end

    test "expired invitation is rejected" do
      create_bare_user!(email: "expired@example.test")
      result = InvitePerson.call(organization: @organization, email: "expired@example.test")
      result.onboarding_request.update!(expires_at: 1.day.ago)

      assert_raises(AcceptInvitation::Expired) do
        AcceptInvitation.call(token: result.token, organization: @organization)
      end
    end

    test "accepting without a resolved account and without a password is rejected" do
      result = InvitePerson.call(organization: @organization, email: "noaccount@example.test")

      assert_raises(AcceptInvitation::AccountRequired) do
        AcceptInvitation.call(token: result.token, organization: @organization)
      end
    end

    test "accepting without a resolved account creates a confirmed, linked account (Flow A/B)" do
      result = InvitePerson.call(
        organization: @organization,
        email: "newaccount@example.test",
        first_name: "New",
        last_name: "Account",
        document_number: "70.707.070-7"
      )

      AcceptInvitation.call(
        token: result.token,
        organization: @organization,
        password: "Password1@"
      )

      person = result.person.reload
      assert person.user_id.present?
      user = person.user
      assert_equal "newaccount@example.test", user.email
      assert user.confirmed?
      assert person.has_role?(AvailableRoles::CLIENT)
      assert_equal OrganizationMembership::STATUS_ACTIVE, person.organization_membership.status
    end

    private

    def create_person!(display_name:, document_number: nil)
      person = Person.new(
        organization: @organization,
        display_name: display_name,
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      person.document_number = document_number if document_number
      person.save!
      person
    end

    def create_bare_user!(email:)
      ActsAsTenant.without_tenant do
        User.create!(
          email: email,
          password: "Password1@",
          password_confirmation: "Password1@",
          name: "Bare User",
          dni: SecureRandom.hex(4),
          language: Languages::ES,
          confirmed_at: Time.current
        )
      end
    end

    def create_org_user!(email:)
      ActsAsTenant.with_tenant(@organization) do
        user = User.create!(
          email: email,
          password: "Password1@",
          password_confirmation: "Password1@",
          name: "Org User",
          dni: SecureRandom.hex(4),
          language: Languages::ES,
          confirmed_at: Time.current
        )
        Accounts::ProvisionTenantIdentity.call(user: user, organization: @organization)
        user
      end
    end
  end
end
