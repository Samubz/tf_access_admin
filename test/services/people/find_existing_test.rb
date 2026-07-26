# frozen_string_literal: true

require "test_helper"

module People
  class FindExistingTest < ActiveSupport::TestCase
    setup do
      @organization = organizations(:one)
      @other_organization = organizations(:two)
      ActsAsTenant.current_tenant = @organization
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    test "returns person matched by document number digest" do
      person = create_person!(
        display_name: "Document Match",
        document_number: "11.111.111-1"
      )

      result = FindExisting.call(
        organization: @organization,
        document_number: "11111111-1"
      )

      assert_equal person, result
    end

    test "returns person matched by email linked to user" do
      user = ActsAsTenant.without_tenant do
        User.create!(
          email: "linked@example.test",
          password: "Password1@",
          password_confirmation: "Password1@",
          name: "Linked Person",
          dni: SecureRandom.hex(4),
          language: Languages::ES,
          confirmed_at: Time.current
        )
      end
      person = Person.create!(
        organization: @organization,
        user: user,
        display_name: "Linked Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )

      result = FindExisting.call(
        organization: @organization,
        email: "LINKED@example.test"
      )

      assert_equal person, result
    end

    test "returns person matched by metadata import_email" do
      person = Person.new(
        organization: @organization,
        display_name: "Metadata Email",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      person.contact_email = "metadata@example.test"
      person.save!

      result = FindExisting.call(
        organization: @organization,
        email: "metadata@example.test"
      )

      assert_equal person, result
    end

    test "prioritizes document match over email match" do
      document_person = create_person!(
        display_name: "Document Person",
        document_number: "22.222.222-2"
      )
      metadata_person = Person.create!(
        organization: @organization,
        display_name: "Email Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE,
        metadata: { "import_email" => "priority@example.test" }
      )

      result = FindExisting.call(
        organization: @organization,
        document_number: "22222222-2",
        email: "priority@example.test"
      )

      assert_equal document_person, result
      refute_equal metadata_person, result
    end

    test "prioritizes user email lookup before metadata import_email in FindExisting" do
      user = ActsAsTenant.without_tenant do
        User.create!(
          email: "priority-user@example.test",
          password: "Password1@",
          password_confirmation: "Password1@",
          name: "User Person",
          dni: SecureRandom.hex(4),
          language: Languages::ES,
          confirmed_at: Time.current
        )
      end
      user_person = Person.create!(
        organization: @organization,
        user: user,
        display_name: "User Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )

      result = People::FindExisting.call(
        organization: @organization,
        email: "priority-user@example.test"
      )

      assert_equal user_person, result
    end

    test "returns nil when no match exists" do
      result = FindExisting.call(
        organization: @organization,
        document_number: "99.999.999-9",
        email: "missing@example.test"
      )

      assert_nil result
    end

    test "excludes soft-deleted people from document match" do
      person = create_person!(
        display_name: "Deleted Person",
        document_number: "33.333.333-3"
      )
      person.destroy

      result = FindExisting.call(
        organization: @organization,
        document_number: "33333333-3"
      )

      assert_nil result
      assert person.reload.deleted?
    end

    test "excludes soft-deleted people from metadata email match" do
      person = Person.new(
        organization: @organization,
        display_name: "Deleted Metadata",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      person.contact_email = "deleted@example.test"
      person.save!
      person.destroy

      result = FindExisting.call(
        organization: @organization,
        email: "deleted@example.test"
      )

      assert_nil result
    end

    test "does not return people from another organization" do
      ActsAsTenant.with_tenant(@other_organization) do
        create_person!(
          organization: @other_organization,
          display_name: "Other Org",
          document_number: "44.444.444-4"
        )
      end

      result = FindExisting.call(
        organization: @organization,
        document_number: "44444444-4"
      )

      assert_nil result
    end

    test "UnitOwnerships::FindExistingPerson delegates with same result" do
      person = create_person!(
        display_name: "Ownership Delegate",
        document_number: "55.555.555-5"
      )

      result = UnitOwnerships::FindExistingPerson.call(
        organization: @organization,
        document_number: "55555555-5",
        email: "unused@example.test"
      )

      assert_equal person, result
    end

    test "ResolveImportOwnerPerson.find_existing delegates with same result" do
      person = create_person!(
        display_name: "Import Delegate",
        document_number: "66.666.666-6"
      )

      result = BulkImportServices::ResolveImportOwnerPerson.find_existing(
        organization: @organization,
        normalized: {
          "owner_document" => "66666666-6",
          "owner_email" => "import@example.test"
        }
      )

      assert_equal person, result
    end

    test "ResolveImportOwnerPerson.find_existing matches email via user" do
      user = ActsAsTenant.without_tenant do
        User.create!(
          email: "import-user@example.test",
          password: "Password1@",
          password_confirmation: "Password1@",
          name: "Import User",
          dni: SecureRandom.hex(4),
          language: Languages::ES,
          confirmed_at: Time.current
        )
      end
      person = Person.create!(
        organization: @organization,
        user: user,
        display_name: "Import User",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )

      result = BulkImportServices::ResolveImportOwnerPerson.find_existing(
        organization: @organization,
        normalized: {
          "owner_document" => "",
          "owner_email" => "import-user@example.test"
        }
      )

      assert_equal person, result
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
  end
end
