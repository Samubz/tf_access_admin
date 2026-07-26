# frozen_string_literal: true

require "test_helper"

class OnboardingMailerTest < ActionMailer::TestCase
  setup do
    @organization = organizations(:one)
  end

  test "invitation names the org, carries the link, and no sensitive data" do
    ActsAsTenant.with_tenant(@organization) do
      person = Person.new(
        organization: @organization,
        display_name: "Invitee",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      person.contact_email = "invitee@example.test"
      person.document_number = "55.555.555-5"
      person.save!

      request = OnboardingRequest.create!(
        organization: @organization,
        person: person,
        requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP,
        status: OnboardingRequest::STATUS_PENDING,
        token_digest: Accounts::InvitePerson.token_digest("rawtoken123"),
        expires_at: 14.days.from_now
      )

      mail = OnboardingMailer.with(onboarding_request: request, token: "rawtoken123").invitation

      assert_equal [ "invitee@example.test" ], mail.to
      assert_match @organization.name, mail.subject

      body = mail.body.encoded
      assert_match "rawtoken123", body                 # the single-use link
      assert_match @organization.name, body            # inviting org disclosed
      assert_no_match(/55\.?555\.?555/, body)          # no document
    end
  end
end
