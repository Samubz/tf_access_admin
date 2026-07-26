# frozen_string_literal: true

class Admin::PersonSerializer < ActiveModel::Serializer
  attributes :id,
    :display_name,
    :first_name,
    :last_name,
    :person_type,
    :status,
    :document_type,
    :document_number,
    :email,
    :phone,
    :birthdate,
    :user_id,
    :user_name,
    :user_email,
    :role,
    :tenant_role,
    :unit_ownerships_count,
    :invitation_status,
    :pending_onboarding_request_id

  def document_number
    object.document_number
  end

  def email
    object.contact_email
  end

  def phone
    object.contact_phone
  end

  def user_name
    object.user&.name
  end

  def user_email
    object.user&.email
  end

  def role
    object.tenant_role
  end

  def tenant_role
    object.tenant_role
  end

  def unit_ownerships_count
    object.unit_ownerships.count
  end

  # Uses the preloaded association (see Admin::PeopleController#index's
  # .includes(:onboarding_requests)) — no N+1 as long as that's preloaded.
  def invitation_status
    return "linked" if object.user_id.present?
    return "pending" if pending_request.present?

    "not_invited"
  end

  def pending_onboarding_request_id
    pending_request&.id
  end

  private

  def pending_request
    object.onboarding_requests.find { |request| request.status == OnboardingRequest::STATUS_PENDING }
  end
end
