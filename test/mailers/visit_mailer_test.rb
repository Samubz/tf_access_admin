# frozen_string_literal: true

require "test_helper"

# property-onboarding "Visit invitation email delivers the acceptance link"
# and residential-visit-management visitor emails (D6).
class VisitMailerTest < ActionMailer::TestCase
  include OperationalPolicyTestHelper

  setup do
    @organization = organizations(:one)
    ActsAsTenant.current_tenant = @organization
    Current.organization = @organization

    @property = create_property(@organization, "Mailer Property")
    @unit = create_unit(@property, "VM-101")
    @host = create_user_for_organization(
      organization: @organization,
      email: "vm-host@example.test",
      role: AvailableRoles::CLIENT,
      name: "Host Name"
    )
    @host.person_for(@organization).update!(contact_phone: "+56999998888", document_number: "22.222.222-2")

    @visitor = Person.new(
      organization: @organization,
      display_name: "Mail Visitor",
      person_type: PersonTypes::NATURAL,
      status: PersonStatuses::ACTIVE
    )
    @visitor.contact_email = "vm-visitor@example.test"
    @visitor.document_number = "33.333.333-3"
    @visitor.contact_phone = "+56977776666"
    @visitor.save!

    @visit = Visit.create!(
      organization: @organization,
      unit: @unit,
      visitor_person: @visitor,
      scheduled_at: Time.zone.parse("2026-09-20 15:30"),
      status: VisitStatuses::AUTHORIZED,
      visit_type: VisitTypes::GUEST,
      created_by: @host,
      authorized_by: @host
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "invitation carries visit details and no PII or link" do
    mail = VisitMailer.with(visit: @visit).invitation

    assert_equal [ "vm-visitor@example.test" ], mail.to
    assert_equal I18n.t("visit_mailer.invitation.subject", property: "Mailer Property"), mail.subject

    body = decoded_body(mail)
    assert_match @organization.name, body
    assert_match "Host Name", body
    assert_match "Mailer Property", body
    assert_match "VM-101", body
    assert_match I18n.l(@visit.scheduled_at, format: :long), body
    assert_no_match(/onboarding\/accept/, body)
    assert_no_pii(body)
  end

  test "invitation_with_account carries the acceptance link and no token outside it" do
    request = OnboardingRequest.create!(
      organization: @organization,
      person: @visitor,
      requested_relationship: OnboardingRequest::RELATIONSHIP_VISITOR,
      status: OnboardingRequest::STATUS_PENDING,
      token_digest: Accounts::InvitePerson.token_digest("rawvisitortoken"),
      expires_at: 14.days.from_now
    )

    mail = VisitMailer.with(visit: @visit, onboarding_request: request, token: "rawvisitortoken").invitation_with_account

    assert_equal [ "vm-visitor@example.test" ], mail.to
    body = decoded_body(mail)
    assert_match "Host Name", body
    assert_match "Mailer Property", body
    assert_match "VM-101", body
    assert_match "#{@organization.subdomain}.", body
    assert_match %r{onboarding/accept/rawvisitortoken}, body
    assert_equal body.scan("rawvisitortoken").size, body.scan("onboarding/accept/rawvisitortoken").size
    assert_match I18n.t("visit_mailer.invitation_with_account.create_account"), body
    assert_no_pii(body)
  end

  test "email is localized with the given locale" do
    mail = VisitMailer.with(visit: @visit, locale: :pt).invitation

    assert_equal I18n.t("visit_mailer.invitation.subject", locale: :pt, property: "Mailer Property"), mail.subject
    assert_match I18n.t("visit_mailer.invitation.greeting", locale: :pt), decoded_body(mail)
  end

  test "email uses the recipient user's language when linked" do
    user = create_user_for_organization(
      organization: @organization,
      email: "vm-linked@example.test",
      role: AvailableRoles::VISITOR
    )
    user.update!(language: Languages::EN)
    @visit.update!(visitor_person: user.person_for(@organization))

    mail = VisitMailer.with(visit: @visit).invitation

    assert_equal [ "vm-linked@example.test" ], mail.to
    assert_equal I18n.t("visit_mailer.invitation.subject", locale: :en, property: "Mailer Property"), mail.subject
  end

  private

  def decoded_body(mail)
    [ mail.text_part, mail.html_part ].compact.map(&:decoded).join("\n")
  end

  def assert_no_pii(body)
    assert_no_match(/22\.?222\.?222/, body)
    assert_no_match(/33\.?333\.?333/, body)
    assert_no_match(/56999998888/, body)
    assert_no_match(/56977776666/, body)
    assert_no_match(/vm-host@example\.test/, body)
  end
end
