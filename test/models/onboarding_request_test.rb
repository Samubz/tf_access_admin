# frozen_string_literal: true

# == Schema Information
#
# Table name: onboarding_requests
#
#  id                      :uuid             not null, primary key
#  conflict_reason         :string
#  deleted_at              :datetime
#  expires_at              :datetime         not null
#  metadata                :jsonb            not null
#  requested_relationship  :string           not null
#  requested_roles         :jsonb            not null
#  status                  :string           default("pending"), not null
#  token_digest            :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  organization_id         :uuid             not null
#  person_id               :uuid
#  requested_by_person_id  :uuid
#  residential_property_id :uuid
#  unit_id                 :uuid
#  user_id                 :uuid
#
# Indexes
#
#  idx_onboarding_requests_unique_pending_scope          (organization_id,person_id,requested_relationship,residential_property_id,unit_id) UNIQUE WHERE (((status)::text = 'pending'::text) AND (deleted_at IS NULL))
#  idx_onboarding_requests_unique_token_digest           (token_digest) UNIQUE WHERE (token_digest IS NOT NULL)
#  index_onboarding_requests_on_deleted_at               (deleted_at)
#  index_onboarding_requests_on_organization_id          (organization_id)
#  index_onboarding_requests_on_person_id                (person_id)
#  index_onboarding_requests_on_requested_by_person_id   (requested_by_person_id)
#  index_onboarding_requests_on_residential_property_id  (residential_property_id)
#  index_onboarding_requests_on_status                   (status)
#  index_onboarding_requests_on_unit_id                  (unit_id)
#  index_onboarding_requests_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (person_id => people.id)
#  fk_rails_...  (requested_by_person_id => people.id)
#  fk_rails_...  (residential_property_id => residential_properties.id)
#  fk_rails_...  (unit_id => units.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class OnboardingRequestTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization

    @person = create_person_in_org(@organization)
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    Current.reset
  end

  test "creates a valid pending request scoped to the tenant" do
    request = build_request

    assert request.valid?, request.errors.full_messages.join(", ")
    assert request.save
    assert_equal OnboardingRequest::STATUS_PENDING, request.status
    assert_equal @organization.id, request.organization_id
  end

  test "requires a known relationship" do
    request = build_request(requested_relationship: "bogus")

    refute request.valid?
    assert request.errors[:requested_relationship].any?
  end

  test "requires an expiration" do
    request = build_request(expires_at: nil)

    refute request.valid?
    assert request.errors[:expires_at].any?
  end

  test "is tenant scoped" do
    request = build_request
    request.save!

    ActsAsTenant.with_tenant(@other_organization) do
      assert_nil OnboardingRequest.find_by(id: request.id)
    end
  end

  test "AASM transitions pending -> accepted / rejected / expired / revoked / conflict" do
    assert build_request.tap(&:save!).accept!
    assert build_request.tap(&:save!).reject!
    assert build_request.tap(&:save!).expire!
    assert build_request.tap(&:save!).revoke!

    conflicted = build_request
    conflicted.save!
    assert conflicted.flag_conflict!
    assert conflicted.revoke!
  end

  # The partial unique index is a best-effort net. Postgres treats NULLs as
  # distinct, so an unscoped membership request (residential_property_id/unit_id
  # NULL) is NOT blocked at the DB level; full pending idempotency is enforced in
  # the service layer (spec §7). This test pins that boundary so it stays explicit.
  test "DB index does not block unscoped membership duplicates (service layer enforces §7)" do
    build_request.save!

    assert_nothing_raised do
      build_request.save!(validate: false)
    end
  end

  test "token_digest is unique when present" do
    build_request(token_digest: "abc123").save!
    duplicate = build_request(
      person: create_person_in_org(@organization, email: "second@example.test"),
      token_digest: "abc123"
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save!(validate: false)
    end
  end

  private

  def build_request(**overrides)
    defaults = {
      organization: @organization,
      person: @person,
      requested_relationship: OnboardingRequest::RELATIONSHIP_MEMBERSHIP,
      expires_at: 7.days.from_now
    }
    OnboardingRequest.new(**defaults.merge(overrides))
  end

  def create_person_in_org(organization, email: "onboarding-test-person@example.test")
    ActsAsTenant.with_tenant(organization) do
      user = User.create!(
        email: email,
        password: "Password1@",
        password_confirmation: "Password1@",
        name: "Test Person",
        dni: SecureRandom.hex(4),
        language: Languages::ES,
        confirmed_at: Time.current
      )
      Accounts::ProvisionTenantIdentity.call(user: user, organization: organization)
      user.person_for(organization)
    end
  end
end
