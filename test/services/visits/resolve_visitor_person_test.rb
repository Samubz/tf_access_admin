# frozen_string_literal: true

require "test_helper"

module Visits
  # Covers OpenSpec residential-visit-management "Visitor person is resolved by
  # email within the organization" (D3): document → email → create; no merges.
  class ResolveVisitorPersonTest < ActiveSupport::TestCase
    setup do
      @organization = organizations(:one)
      @other_organization = organizations(:two)
      ActsAsTenant.current_tenant = @organization
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    test "reuses existing person by email case-insensitively" do
      existing = build_person(email: "ana@example.com", display_name: "Ana")
      existing.save!

      result = nil
      assert_no_difference "Person.count" do
        result = ResolveVisitorPerson.call(
          organization: @organization,
          person_params: { display_name: "Ana Other", email: "  Ana@Example.com " }
        )
      end

      assert_equal existing, result
    end

    test "prefers document match over email match" do
      by_doc = build_person(email: "doc@example.com", display_name: "Doc", document_number: "77.777.777-7")
      by_doc.save!

      result = ResolveVisitorPerson.call(
        organization: @organization,
        person_params: { display_name: "X", email: "doc@example.com", document_number: "77777777-7" }
      )

      assert_equal by_doc, result
    end

    test "creates a new person with display name, email, phone and document" do
      result = nil
      assert_difference "Person.count", 1 do
        result = ResolveVisitorPerson.call(
          organization: @organization,
          person_params: {
            display_name: "Nueva Persona", email: "Nueva@Example.com",
            phone: "+56911111111", document_number: "88.888.888-8"
          }
        )
      end

      assert_equal @organization.id, result.organization_id
      assert_equal "Nueva Persona", result.display_name
      assert_equal "nueva@example.com", result.contact_email
      assert_equal "+56911111111", result.contact_phone
      assert_equal Person.document_digest("88.888.888-8"), result.document_number_digest
      assert_equal Person.email_digest("nueva@example.com"), result.email_digest
    end

    test "same email in another organization creates a separate person" do
      ActsAsTenant.with_tenant(@other_organization) do
        build_person(email: "shared@example.com", display_name: "Other", organization: @other_organization).save!
      end

      assert_difference "Person.where(organization_id: @organization.id).count", 1 do
        ResolveVisitorPerson.call(
          organization: @organization,
          person_params: { display_name: "Shared", email: "shared@example.com" }
        )
      end
    end

    test "raises IdentityConflict when document matches a person with a different email" do
      build_person(email: "x@example.com", display_name: "X", document_number: "99.999.999-9").save!

      assert_no_difference "Person.count" do
        assert_raises(ResolveVisitorPerson::IdentityConflict) do
          ResolveVisitorPerson.call(
            organization: @organization,
            person_params: { display_name: "Y", email: "y@example.com", document_number: "99999999-9" }
          )
        end
      end
    end

    test "document match with no stored email is reused without conflict" do
      person = build_person(display_name: "No Email", document_number: "66.666.666-6")
      person.save!

      result = ResolveVisitorPerson.call(
        organization: @organization,
        person_params: { display_name: "No Email", email: "new@example.com", document_number: "66666666-6" }
      )

      assert_equal person, result
    end

    private

    def build_person(display_name:, email: nil, document_number: nil, organization: @organization)
      person = Person.new(
        organization: organization,
        display_name: display_name,
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      person.contact_email = email if email
      person.document_number = document_number if document_number
      person
    end
  end
end
