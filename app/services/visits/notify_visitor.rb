# frozen_string_literal: true

module Visits
  # Notifies the visitor of a freshly created visit (D4). Runs OUTSIDE the
  # creation transaction and never raises: any failure is logged and recorded
  # in +visit.metadata["visitor_notification_error"]+.
  #
  # Branches on +person = visit.visitor_person+:
  #   1. person.user present            → push Notification (visit_invitation) + invitation email
  #   2. confirmed User with same email → link + visitor membership/role, then as 1
  #   3. no User                        → visitor OnboardingRequest + invitation_with_account
  #      (pending request already exists → no new token, plain invitation email)
  class NotifyVisitor
    METADATA_ERROR_KEY = "visitor_notification_error"

    def self.call(visit:, actor:)
      new(visit:, actor:).call
    end

    def initialize(visit:, actor:)
      @visit = visit
      @actor = actor
    end

    def call
      person = @visit.visitor_person
      return if person.blank?

      if person.user.present?
        notify_linked(person)
      elsif (user = confirmed_user_for(person))
        link_and_activate(person, user)
        notify_linked(person)
      else
        invite_to_create_account(person)
      end
    rescue StandardError => e
      Rails.logger.error("[Visits::NotifyVisitor] visit=#{@visit.id} #{e.class}: #{e.message}")
      record_error(e)
      nil
    end

    private

    # Branch 1
    def notify_linked(person)
      notification = Notification.create!(
        organization: @visit.organization,
        recipient_person: person,
        unit: @visit.unit,
        residential_property: @visit.residential_property,
        notifiable: @visit,
        notification_type: NotificationTypes::VISIT_INVITATION,
        channel: NotificationChannels::PUSH,
        status: NotificationStatuses::PENDING
      )
      DeliverPushNotificationJob.perform_later(notification.id)
      VisitMailer.with(visit: @visit).invitation.deliver_later
    end

    # Branch 2
    def confirmed_user_for(person)
      email = person.contact_email.to_s.downcase.strip.presence
      return nil if email.blank?

      ActsAsTenant.without_tenant do
        User.where("LOWER(email) = ?", email).where.not(confirmed_at: nil).first
      end
    end

    def link_and_activate(person, user)
      organization = @visit.organization

      ActiveRecord::Base.transaction do
        Accounts::LinkUserToPerson.call(person: person, user: user)

        membership = person.organization_membership ||
          OrganizationMembership.create!(organization: organization, person: person)
        membership.accept! if membership.may_accept?

        person.add_role(AvailableRoles::VISITOR, organization) unless person.has_role?(AvailableRoles::VISITOR, organization)
      end
    end

    # Branch 3
    def invite_to_create_account(person)
      result = Accounts::InvitePerson.call_for_person(
        person: person,
        requested_relationship: OnboardingRequest::RELATIONSHIP_VISITOR,
        requested_by_person: @actor&.person_for(@visit.organization)
      )

      VisitMailer.with(visit: @visit, onboarding_request: result.onboarding_request, token: result.token)
                 .invitation_with_account.deliver_later
    rescue Accounts::InvitePerson::AlreadyInvited
      # Pending request stays as-is (no new token): send the detail-only reminder.
      VisitMailer.with(visit: @visit).invitation.deliver_later
    end

    def record_error(error)
      metadata = (@visit.metadata || {}).merge(METADATA_ERROR_KEY => "#{error.class}: #{error.message}")
      @visit.update_column(:metadata, metadata) # rubocop:disable Rails/SkipsModelValidations
    rescue StandardError => e
      Rails.logger.error("[Visits::NotifyVisitor] could not record error on visit=#{@visit.id}: #{e.message}")
    end
  end
end
