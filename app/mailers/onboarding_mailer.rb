# frozen_string_literal: true

# Delivers an onboarding invitation as a single-use, expiring link. Carries only
# the link and the inviting organization's name — no document, no other emails,
# no other organizations, and no token outside the link.
#
# Parameterized style: OnboardingMailer.with(onboarding_request:, token:, locale:).invitation
class OnboardingMailer < ApplicationMailer
  def invitation
    @request = params[:onboarding_request]
    @token = params[:token]
    @organization = @request.organization
    @accept_url = onboarding_acceptance_url(@token, **tenant_url_options_for(@request))

    mail(
      to: recipient_email,
      subject: I18n.t("onboarding_mailer.invitation.subject", organization: @organization.name)
    )
  end

  private

  def recipient_email
    params[:email].presence || @request.person&.contact_email
  end
end
