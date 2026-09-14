# frozen_string_literal: true

# Visitor-facing visit invitation emails (D6). Carries the organization, host
# display name, property, unit and scheduled date/time — never documents,
# phone numbers, other people's emails, nor the token outside the link.
#
#   VisitMailer.with(visit:).invitation
#   VisitMailer.with(visit:, onboarding_request:, token:).invitation_with_account
#
# Locale: explicit +locale+ param, else the visitor user's language (when the
# person is linked), else I18n.default_locale.
class VisitMailer < ApplicationMailer
  before_action :load_visit

  def invitation
    mail(to: recipient_email, subject: subject_line)
  end

  def invitation_with_account
    @onboarding_request = params[:onboarding_request]
    @accept_url = onboarding_acceptance_url(params[:token], **tenant_url_options_for(@visit))

    mail(to: recipient_email, subject: subject_line)
  end

  private

  def load_visit
    @visit = params[:visit]
    @organization = @visit.organization
    @property = @visit.residential_property
    @unit = @visit.unit
    @host_name = @visit.created_by&.name
    @scheduled_at = I18n.l(@visit.scheduled_at, format: :long)
  end

  def recipient_email
    @visit.visitor_person&.contact_email
  end

  def subject_line
    I18n.t("visit_mailer.#{action_name}.subject", property: @property&.name)
  end

  # Visitor's own language wins over the default when the person is linked.
  def apply_mail_locale(&block)
    locale = params[:locale].presence || params[:visit]&.visitor_person&.user&.language.presence || I18n.default_locale
    I18n.with_locale(locale, &block)
  end
end
