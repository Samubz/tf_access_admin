# frozen_string_literal: true

require "test_helper"

module Memberships
  class OnboardingLifecycleTest < ActiveSupport::TestCase
    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization
      @property = ResidentialProperty.create!(
        organization: @organization,
        name: "Lifecycle Property",
        property_type: PropertyTypes::BUILDING,
        status: "active",
        country: "Chile",
        timezone: "America/Santiago"
      )
      @actor = create_person!(display_name: "Manager")
    end

    teardown do
      ActsAsTenant.current_tenant = nil
      Current.reset
    end

    # --- Accounts::LinkUserToPerson -----------------------------------------

    test "links a user to a person and is idempotent" do
      person = create_person!(display_name: "To Link")
      user = create_bare_user!(email: "link@example.test")

      Accounts::LinkUserToPerson.call(person: person, user: user)
      assert_equal user.id, person.reload.user_id

      # second call is a no-op, not a conflict
      assert_nothing_raised { Accounts::LinkUserToPerson.call(person: person, user: user) }
    end

    test "raises when person is already linked to a different user" do
      person = create_person!(display_name: "Linked")
      first = create_bare_user!(email: "first@example.test")
      second = create_bare_user!(email: "second@example.test")
      Accounts::LinkUserToPerson.call(person: person, user: first)

      assert_raises(Accounts::LinkUserToPerson::Conflict) do
        Accounts::LinkUserToPerson.call(person: person, user: second)
      end
    end

    # --- Client onboarding (active-declinable) ------------------------------

    test "client onboarding activates membership and grants client role immediately" do
      person = create_person!(display_name: "Client")

      request = RequestOnboarding.call(
        organization: @organization,
        person: person,
        requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP,
        requested_by_person: @actor
      )

      assert request.accepted?
      assert person.has_role?(AvailableRoles::CLIENT)
      assert_equal OrganizationMembership::STATUS_ACTIVE, person.organization_membership.status
    end

    test "client onboarding is idempotent" do
      person = create_person!(display_name: "Client Idem")
      first = RequestOnboarding.call(organization: @organization, person: person,
                                     requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP)
      second = RequestOnboarding.call(organization: @organization, person: person,
                                      requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP)

      assert_equal first.id, second.id
      assert_equal 1, OnboardingRequest.where(person_id: person.id).count
    end

    test "client can decline: membership revoked and user unlinked, person kept" do
      person = create_person!(display_name: "Decline")
      user = create_bare_user!(email: "decline@example.test")
      Accounts::LinkUserToPerson.call(person: person, user: user)
      RequestOnboarding.call(organization: @organization, person: person,
                             requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP)

      Revoke.call(membership: person.organization_membership, unlink_user: true)

      assert_equal OrganizationMembership::STATUS_REVOKED, person.organization_membership.status
      assert_nil person.reload.user_id
      assert Person.exists?(person.id)
    end

    # --- Operational onboarding (pending-confirmable) -----------------------

    test "operational onboarding creates a pending request and unconfirmed role, no active membership" do
      person = create_person!(display_name: "Operational")

      request = RequestOnboarding.call(
        organization: @organization,
        person: person,
        requested_relationship: OnboardingRequest::RELATIONSHIP_STAFF,
        residential_property: @property,
        staff_type: StaffTypes::CONCIERGE
      )

      assert request.pending?
      assignment = StaffAssignment.find_by(person_id: person.id)
      assert_equal StaffAssignment::CONFIRMATION_PENDING, assignment.confirmation_state
      assert_nil person.organization_membership
    end

    test "accepting an operational request activates membership and confirms the role" do
      person = create_person!(display_name: "Op Accept")
      request = RequestOnboarding.call(
        organization: @organization, person: person,
        requested_relationship: OnboardingRequest::RELATIONSHIP_STAFF,
        residential_property: @property, staff_type: StaffTypes::CONCIERGE
      )

      AcceptOnboarding.call(onboarding_request: request)

      assert request.reload.accepted?
      assert_equal OrganizationMembership::STATUS_ACTIVE, person.organization_membership.status
      assert StaffAssignment.find_by(person_id: person.id).confirmed?
    end

    test "rejecting an operational request deactivates the pending role" do
      person = create_person!(display_name: "Op Reject")
      request = RequestOnboarding.call(
        organization: @organization, person: person,
        requested_relationship: OnboardingRequest::RELATIONSHIP_STAFF,
        residential_property: @property, staff_type: StaffTypes::CLEANING
      )

      RejectOnboarding.call(onboarding_request: request)

      assert request.reload.rejected?
      assert_equal StaffAssignment::STATUS_INACTIVE, StaffAssignment.find_by(person_id: person.id).status
    end

    # --- Conflict -----------------------------------------------------------

    test "records a conflict without creating a membership" do
      other_user = create_bare_user_with_person!(email: "conflict@example.test")
      person_a = create_person!(display_name: "Conflict A", document_number: "77.777.777-7")
      person_a.contact_email = "conflict@example.test"

      request = RequestOnboarding.call(
        organization: @organization,
        person: person_a,
        requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP
      )

      assert request.conflict?
      assert_equal "email_belongs_to_other_account", request.conflict_reason
      assert_nil person_a.reload.organization_membership
      refute person_a.has_role?(AvailableRoles::CLIENT)
      assert other_user
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

    # A user with no auto-provisioned person in this org (created in another tenant).
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

    # A user whose provisioned person lives in @organization.
    def create_bare_user_with_person!(email:)
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
