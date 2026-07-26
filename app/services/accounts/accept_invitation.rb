# frozen_string_literal: true

module Accounts
  # Accepts an account invitation by its single-use token, verifying the token
  # digest, expiration, and pending state before granting anything (possession
  # of the link alone is insufficient — the holder must be the resolved account).
  #
  # - Existing account (Flow C): links the account to the person.
  # - No account (Flow A/B): creates the `User` from the holder-provided password
  #   (and optional name/dni/language, falling back to the person's data).
  #
  # Accepting by token confirms the email in both cases (opening the single-use
  # link proves possession), so no separate confirmation email is required.
  class AcceptInvitation
    class InvalidToken < StandardError; end
    class Expired < StandardError; end
    class AccountRequired < StandardError; end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(token:, organization:, password: nil, name: nil, dni: nil, language: nil)
      @token = token
      @organization = organization
      @password = password
      @name = name
      @dni = dni
      @language = language
    end

    def call
      request = find_pending_request!
      raise Expired if request.expires_at.past?

      OnboardingRequest.transaction do
        user = request.user || existing_account_for(request) || create_account!(request)
        confirm_email(user)
        Accounts::LinkUserToPerson.call(person: request.person, user: user)
        consume_token(request)
        Memberships::AcceptOnboarding.call(onboarding_request: request)
      end
    end

    private

    def find_pending_request!
      digest = Accounts::InvitePerson.token_digest(@token)
      request = OnboardingRequest.where(organization_id: @organization.id, token_digest: digest).first
      raise InvalidToken if request.blank? || !request.pending?

      request
    end

    def existing_account_for(request)
      Accounts::InvitePerson.user_for_contact_email(request.person)
    rescue Accounts::InvitePerson::AlreadyInvited
      nil
    end

    def create_account!(request)
      raise AccountRequired, "password is required to create an account" if @password.blank?

      person = request.person
      user = User.new(
        email: person.contact_email,
        password: @password,
        password_confirmation: @password,
        name: @name.presence || person.display_name,
        dni: @dni.presence || person.document_number,
        language: @language.presence || I18n.default_locale.to_s
      )
      user.skip_confirmation!
      user.save!
      user
    end

    # Opening the single-use link proves email possession → confirm the account.
    def confirm_email(user)
      return if user.confirmed_at.present?

      user.update!(confirmed_at: Time.current)
    end

    def consume_token(request)
      request.update!(token_digest: nil)
    end
  end
end
