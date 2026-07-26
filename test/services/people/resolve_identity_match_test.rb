# frozen_string_literal: true

require "test_helper"

module People
  class ResolveIdentityMatchTest < ActiveSupport::TestCase
    setup do
      @organization = organizations(:one)
      @other_organization = organizations(:two)
      ActsAsTenant.current_tenant = @organization
    end

    teardown do
      ActsAsTenant.current_tenant = nil
      Current.reset
    end

    test "returns none when nothing matches" do
      result = ResolveIdentityMatch.call(
        organization: @organization,
        document_number: "99.999.999-9",
        email: "missing@example.test"
      )

      assert result.none?
      assert_nil result.person
      assert_nil result.user
    end

    test "matches a person by document with no linked account" do
      person = create_person!(display_name: "Doc Only", document_number: "11.111.111-1")

      result = ResolveIdentityMatch.call(organization: @organization, document_number: "11111111-1")

      assert result.person?
      assert_equal person, result.person
      assert_nil result.user
    end

    test "email resolves an existing account with no person in the org as matched_account" do
      user = create_user!(email: "account@example.test", organization: @other_organization)

      result = ResolveIdentityMatch.call(organization: @organization, email: "ACCOUNT@example.test")

      assert result.account?
      assert_nil result.person
      assert_equal user, result.user
    end

    test "email resolves to the person linked to the account in the org" do
      user = create_user!(email: "member@example.test", organization: @organization)
      person = user.person_for(@organization)

      result = ResolveIdentityMatch.call(organization: @organization, email: "member@example.test")

      assert result.person?
      assert_equal person, result.person
      assert_equal user, result.user
    end

    test "conflict when document matches person A but email belongs to another account linked to person B" do
      user_b = create_user!(email: "personb@example.test", organization: @organization)
      person_b = user_b.person_for(@organization)
      person_b.update!(display_name: "Person B")

      person_a = create_person!(display_name: "Person A", document_number: "22.222.222-2")

      result = ResolveIdentityMatch.call(
        organization: @organization,
        document_number: "22222222-2",
        email: "personb@example.test"
      )

      assert result.conflict?
      assert_equal person_a, result.person
      assert_equal "email_belongs_to_other_account", result.conflict_reason
      # No association changed.
      assert_nil person_a.reload.user
      assert_equal person_b, user_b.person_for(@organization)
    end

    test "matched person by metadata email when no account exists" do
      person = Person.new(
        organization: @organization,
        display_name: "Metadata Only",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      person.contact_email = "meta@example.test"
      person.save!

      result = ResolveIdentityMatch.call(organization: @organization, email: "meta@example.test")

      assert result.person?
      assert_equal person, result.person
      assert_nil result.user
    end

    test "does not match a person from another organization" do
      ActsAsTenant.with_tenant(@other_organization) do
        create_person!(
          display_name: "Other Org",
          document_number: "44.444.444-4",
          organization: @other_organization
        )
      end

      result = ResolveIdentityMatch.call(organization: @organization, document_number: "44444444-4")

      assert result.none?
    end

    private

    def create_person!(display_name:, document_number:, organization: @organization)
      person = Person.new(
        organization: organization,
        display_name: display_name,
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      person.document_number = document_number
      person.save!
      person
    end

    def create_user!(email:, organization:)
      ActsAsTenant.with_tenant(organization) do
        user = User.create!(
          email: email,
          password: "Password1@",
          password_confirmation: "Password1@",
          name: "Test User",
          dni: SecureRandom.hex(4),
          language: Languages::ES,
          confirmed_at: Time.current
        )
        Accounts::ProvisionTenantIdentity.call(user: user, organization: organization)
        user
      end
    end
  end
end
