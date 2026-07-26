# frozen_string_literal: true

# Holder-facing acceptance of an onboarding invitation by single-use token.
# Neutral: shows only the inviting organization and whether an account must be
# created. Never lists other organizations. Possession of the link is not enough
# — accepting creates/links the account and confirms the email.
class OnboardingAcceptancesController < ApplicationController
  def show
    request = find_request
    return render_invalid unless acceptable?(request)

    render inertia: "onboarding/accept", props: {
      token: params[:token],
      organization_name: request.organization.name,
      needs_account: existing_account_for(request).blank?,
      email: masked_email(request)
    }
  end

  def create
    request = find_request
    return render_invalid unless acceptable?(request)

    ActsAsTenant.with_tenant(request.organization) do
      Accounts::AcceptInvitation.call(
        token: params[:token],
        organization: request.organization,
        password: params[:password],
        name: params[:name],
        dni: params[:dni]
      )
    end

    flash[:notice] = I18n.t("onboarding.accept.success")
    inertia_location(new_user_session_path)
  rescue Accounts::AcceptInvitation::AccountRequired, ActiveRecord::RecordInvalid => e
    redirect_to onboarding_acceptance_path(params[:token]),
                inertia: { errors: { base: [ e.message ] } }
  rescue Accounts::AcceptInvitation::InvalidToken, Accounts::AcceptInvitation::Expired
    render_invalid
  end

  private

  def find_request
    digest = Accounts::InvitePerson.token_digest(params[:token])
    ActsAsTenant.without_tenant { OnboardingRequest.find_by(token_digest: digest) }
  end

  def acceptable?(request)
    request.present? && request.pending? && request.expires_at.future?
  end

  def existing_account_for(request)
    request.user || Accounts::InvitePerson.user_for_contact_email(request.person)
  rescue Accounts::InvitePerson::AlreadyInvited
    nil
  end

  def masked_email(request)
    email = request.person&.contact_email
    return nil if email.blank?

    name, domain = email.split("@", 2)
    return email if name.blank? || domain.blank?

    "#{name[0]}***@#{domain}"
  end

  def render_invalid
    render inertia: "onboarding/invalid", props: {}, status: :unprocessable_entity
  end
end
