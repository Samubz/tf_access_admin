# frozen_string_literal: true

# GET/PATCH /api/v1/private/me — authenticated user's profile.
# +name+ and +avatar+ live on User; +phone+ and +dateOfBirth+ on the Person of
# the current organization. +gender+ is accepted but ignored (not modelled).
class Api::V1::Private::ProfilesController < Api::V1::Private::BaseController
  def show
    render_profile
  end

  def update
    ActiveRecord::Base.transaction do
      current_user.update!(name: params[:name]) if params.key?(:name)
      current_user.avatar.attach(params[:avatar]) if params[:avatar].present?
      update_person!
    end

    render_profile
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  rescue Date::Error
    render json: { error: I18n.t("api.errors.invalid_day") }, status: :unprocessable_entity
  end

  private

  def render_profile
    render_resource(current_user.reload,
                    serializer: Api::Private::ProfileSerializer,
                    organization: ActsAsTenant.current_tenant)
  end

  def update_person!
    person = current_user.person_for(ActsAsTenant.current_tenant)
    return if person.blank?

    if params.key?(:phone)
      phone = params[:phone]
      person.contact_phone = phone.present? ? Api::Private::PhoneNumber.join(phone[:countryCode], phone[:number]) : nil
    end
    person.birthdate = params[:dateOfBirth].present? ? Date.iso8601(params[:dateOfBirth].to_s) : nil if params.key?(:dateOfBirth)

    person.save!
  end
end
