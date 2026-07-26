# frozen_string_literal: true

require "test_helper"

module BulkImportServices
  class ClassifyPeopleRowTest < ActiveSupport::TestCase
    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization
    end

    teardown do
      ActsAsTenant.current_tenant = nil
      Current.reset
    end

    test "invalid when no email and no document" do
      result = ClassifyPeopleRow.call(organization: @organization)
      assert result.invalid?
    end

    test "ready to create when nothing matches" do
      result = ClassifyPeopleRow.call(organization: @organization, document_number: "10.101.010-1")
      assert_equal ClassifyPeopleRow::READY_TO_CREATE_PERSON, result.classification
    end

    test "requires invitation when person exists without an account" do
      person = create_person!(display_name: "No Account", document_number: "20.202.020-2")

      result = ClassifyPeopleRow.call(organization: @organization, document_number: "20202020-2")

      assert_equal ClassifyPeopleRow::REQUIRES_INVITATION, result.classification
      assert_equal person, result.person
    end

    test "requires incorporation when the account exists without a person in the org" do
      user = create_bare_user!(email: "acct@example.test")

      result = ClassifyPeopleRow.call(organization: @organization, email: "acct@example.test")

      assert_equal ClassifyPeopleRow::REQUIRES_INCORPORATION, result.classification
      assert_equal user, result.user
    end

    test "duplicate when the person already has an active membership" do
      user = create_org_user!(email: "member@example.test")
      person = user.person_for(@organization)
      person.update!(display_name: "Member")

      result = ClassifyPeopleRow.call(organization: @organization, email: "member@example.test")

      assert_equal ClassifyPeopleRow::DUPLICATE, result.classification
      assert_equal person, result.person
    end

    test "duplicate when a pending onboarding request already exists" do
      person = create_person!(display_name: "Pending", document_number: "30.303.030-3")
      OnboardingRequest.create!(
        organization: @organization, person: person,
        requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP,
        status: OnboardingRequest::STATUS_PENDING, expires_at: 7.days.from_now
      )

      result = ClassifyPeopleRow.call(organization: @organization, document_number: "30303030-3")

      assert_equal ClassifyPeopleRow::DUPLICATE, result.classification
    end

    test "conflict when document and email resolve to different identities" do
      create_org_user!(email: "taken@example.test")
      create_person!(display_name: "Conflict", document_number: "40.404.040-4")

      result = ClassifyPeopleRow.call(
        organization: @organization,
        document_number: "40404040-4",
        email: "taken@example.test"
      )

      assert result.conflict?
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
