# frozen_string_literal: true

require "test_helper"

module Visits
  # residential-visit-management "Visitor is notified after the visit is created" (D4).
  class NotifyVisitorTest < ActiveSupport::TestCase
    include OperationalPolicyTestHelper
    include ActiveJob::TestHelper
    include ActionMailer::TestHelper

    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization
      Current.organization = @organization

      @property = create_property(@organization, "Notify Property")
      @unit = create_unit(@property, "NV-101")
      @host = create_user_for_organization(
        organization: @organization,
        email: "nv-host@example.test",
        role: AvailableRoles::CLIENT
      )
    end

    teardown do
      ActsAsTenant.current_tenant = nil
      Current.reset
    end

    test "linked account: enqueues visit_invitation push and invitation email" do
      visitor_user = create_user_for_organization(
        organization: @organization,
        email: "nv-linked@example.test",
        role: AvailableRoles::VISITOR
      )
      visit = create_visit(visitor_user.person_for(@organization))

      assert_enqueued_emails 1 do
        assert_enqueued_with(job: DeliverPushNotificationJob) do
          NotifyVisitor.call(visit: visit, actor: @host)
        end
      end

      notification = Notification.find_by(notifiable: visit, notification_type: NotificationTypes::VISIT_INVITATION)
      assert notification
      assert_equal NotificationChannels::PUSH, notification.channel
      assert_equal visitor_user.person_for(@organization), notification.recipient_person
      assert_enqueued_email_with VisitMailer, :invitation, params: { visit: visit }
      assert_equal 0, OnboardingRequest.where(person: visit.visitor_person).count
    end

    test "existing confirmed account: links user, activates visitor membership and notifies" do
      user = create_confirmed_user(email: "nv-existing@example.test", name: "Existing")
      person = build_visitor_person("nv-existing@example.test")
      visit = create_visit(person)

      assert_enqueued_emails 1 do
        assert_enqueued_with(job: DeliverPushNotificationJob) do
          NotifyVisitor.call(visit: visit, actor: @host)
        end
      end

      person.reload
      assert_equal user.id, person.user_id
      assert_equal OrganizationMembership::STATUS_ACTIVE, person.organization_membership.status
      assert person.has_role?(AvailableRoles::VISITOR, @organization)
      assert Notification.exists?(notifiable: visit, notification_type: NotificationTypes::VISIT_INVITATION)
      assert_enqueued_email_with VisitMailer, :invitation, params: { visit: visit }
    end

    test "unconfirmed account is not linked: falls back to onboarding invitation" do
      user = User.new(
        email: "nv-unconfirmed@example.test", password: "Password1@", password_confirmation: "Password1@",
        name: "Unconfirmed", dni: SecureRandom.hex(4), language: Languages::ES
      )
      user.skip_confirmation_notification!
      user.save!
      assert_nil user.confirmed_at
      person = build_visitor_person("nv-unconfirmed@example.test")
      visit = create_visit(person)

      NotifyVisitor.call(visit: visit, actor: @host)

      assert_nil person.reload.user_id
      assert_equal 1, OnboardingRequest.where(person: person, status: OnboardingRequest::STATUS_PENDING).count
    end

    test "no account: issues a visitor onboarding request and emails the acceptance link" do
      person = build_visitor_person("nv-new@example.test")
      visit = create_visit(person)

      assert_no_enqueued_jobs(only: DeliverPushNotificationJob) do
        assert_enqueued_emails 1 do
          NotifyVisitor.call(visit: visit, actor: @host)
        end
      end

      request = OnboardingRequest.find_by!(person: person)
      assert_equal OnboardingRequest::RELATIONSHIP_VISITOR, request.requested_relationship
      assert_equal OnboardingRequest::STATUS_PENDING, request.status
      assert_equal @host.person_for(@organization), request.requested_by_person
      assert_nil person.reload.user_id

      enqueued = enqueued_jobs.find { |j| j["job_class"] == "ActionMailer::MailDeliveryJob" }
      args = enqueued["arguments"]
      assert_equal "VisitMailer", args[0]
      assert_equal "invitation_with_account", args[1]
      params = ActiveJob::Arguments.deserialize(args)[3][:params]
      assert_equal visit, params[:visit]
      assert_equal request, params[:onboarding_request]
      assert_equal request.token_digest, Accounts::InvitePerson.token_digest(params[:token])
    end

    test "pending invitation is reused without a new token and the plain invitation is sent" do
      person = build_visitor_person("nv-pending@example.test")
      existing = Accounts::InvitePerson.call_for_person(
        person: person,
        requested_relationship: OnboardingRequest::RELATIONSHIP_VISITOR
      ).onboarding_request
      original_digest = existing.token_digest
      visit = create_visit(person)

      assert_enqueued_emails 1 do
        NotifyVisitor.call(visit: visit, actor: @host)
      end

      assert_equal 1, OnboardingRequest.where(person: person).count
      assert_equal original_digest, existing.reload.token_digest
      assert_enqueued_email_with VisitMailer, :invitation, params: { visit: visit }
    end

    test "unexpected error is recorded on the visit metadata and never raised" do
      person = build_visitor_person("nv-error@example.test")
      visit = create_visit(person)

      with_failing_invite do
        assert_nothing_raised { NotifyVisitor.call(visit: visit, actor: @host) }
      end

      visit.reload
      assert_equal VisitStatuses::AUTHORIZED, visit.status
      assert_match "boom", visit.metadata["visitor_notification_error"]
    end

    private

    # Temporarily makes Accounts::InvitePerson.call_for_person raise.
    def with_failing_invite
      singleton = Accounts::InvitePerson.singleton_class
      original = singleton.instance_method(:call_for_person)
      singleton.define_method(:call_for_person) { |**| raise "boom" }
      yield
    ensure
      singleton.define_method(:call_for_person, original)
    end

    def build_visitor_person(email)
      person = Person.new(
        organization: @organization,
        display_name: "Visitor #{email}",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      person.contact_email = email
      person.save!
      person
    end

    def create_visit(person)
      Visit.create!(
        organization: @organization,
        unit: @unit,
        visitor_person: person,
        scheduled_at: 1.day.from_now,
        status: VisitStatuses::AUTHORIZED,
        visit_type: VisitTypes::GUEST,
        created_by: @host,
        authorized_by: @host
      )
    end
  end
end
