# frozen_string_literal: true

require "test_helper"

module IdentityConflicts
  class ResolveTest < ActiveSupport::TestCase
    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization
      @actor = create_person!(display_name: "Resolver")
    end

    teardown do
      ActsAsTenant.current_tenant = nil
      Current.reset
    end

    test "dismiss revokes the conflict request without changing associations" do
      request = conflict_request

      Resolve.call(onboarding_request: request, decision: :dismiss, resolved_by: @actor)

      assert request.reload.revoked?
      assert_equal "dismiss", request.metadata.dig("resolution", "decision")
      assert_nil request.person&.reload&.user_id
    end

    test "link joins the asserted person and account, then revokes the conflict" do
      request = conflict_request
      person = create_person!(display_name: "Verified Person")
      user = create_bare_user!(email: "verified@example.test")

      Resolve.call(onboarding_request: request, decision: :link, resolved_by: @actor,
                   person: person, user: user)

      assert_equal user.id, person.reload.user_id
      assert request.reload.revoked?
      assert_equal "link", request.metadata.dig("resolution", "decision")
    end

    test "link without a target raises" do
      request = conflict_request

      assert_raises(Resolve::MissingTarget) do
        Resolve.call(onboarding_request: request, decision: :link, resolved_by: @actor)
      end
    end

    test "raises when the request is not a conflict" do
      person = create_person!(display_name: "Plain")
      request = Memberships::RequestOnboarding.call(
        organization: @organization, person: person,
        requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP
      )

      assert_raises(Resolve::NotAConflict) do
        Resolve.call(onboarding_request: request, decision: :dismiss)
      end
    end

    private

    def conflict_request
      create_org_user!(email: "conflict@example.test")
      person_a = create_person!(display_name: "Conflict A", document_number: "90.909.090-9")
      person_a.contact_email = "conflict@example.test"

      request = Memberships::RequestOnboarding.call(
        organization: @organization,
        person: person_a,
        requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP
      )
      assert request.conflict?, "expected a conflict request in setup"
      request
    end

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
        User.create!(email: email, password: "Password1@", password_confirmation: "Password1@",
                     name: "Bare", dni: SecureRandom.hex(4), language: Languages::ES,
                     confirmed_at: Time.current)
      end
    end

    def create_org_user!(email:)
      ActsAsTenant.with_tenant(@organization) do
        user = User.create!(email: email, password: "Password1@", password_confirmation: "Password1@",
                            name: "Org", dni: SecureRandom.hex(4), language: Languages::ES,
                            confirmed_at: Time.current)
        Accounts::ProvisionTenantIdentity.call(user: user, organization: @organization)
        user
      end
    end
  end
end
