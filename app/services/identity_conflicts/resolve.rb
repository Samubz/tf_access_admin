# frozen_string_literal: true

module IdentityConflicts
  # Resolves a conflict onboarding request explicitly. A conflict is recorded
  # without changing any association (see +People::ResolveIdentityMatch+); this
  # service applies a human decision:
  #
  # - :dismiss → revoke the conflict request; no identity is changed.
  # - :link    → an authorized actor asserts the correct person↔account after
  #              verification; links them and revokes the conflict request so a
  #              clean onboarding can be re-initiated.
  #
  # Authorization is enforced by the policy layer via the dedicated capability
  # +resolve_identity_conflicts+ (wired in tasks §14) — this service is the
  # domain operation, not the gate. It never exposes other organizations' data.
  class Resolve
    class NotAConflict < StandardError; end
    class MissingTarget < StandardError; end

    DECISION_DISMISS = :dismiss
    DECISION_LINK = :link
    DECISIONS = [ DECISION_DISMISS, DECISION_LINK ].freeze

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(onboarding_request:, decision:, resolved_by: nil, person: nil, user: nil)
      @request = onboarding_request
      @decision = decision.to_sym
      @resolved_by = resolved_by
      @person = person
      @user = user
    end

    def call
      raise NotAConflict, "onboarding request is not in conflict" unless @request.conflict?
      raise ArgumentError, "unknown decision #{@decision.inspect}" unless DECISIONS.include?(@decision)

      OnboardingRequest.transaction do
        case @decision
        when DECISION_DISMISS then dismiss
        when DECISION_LINK    then link
        end
        @request
      end
    end

    private

    def dismiss
      stamp_resolution(DECISION_DISMISS)
      @request.revoke! if @request.may_revoke?
    end

    def link
      raise MissingTarget, "link requires an explicit person and user" if @person.blank? || @user.blank?

      Accounts::LinkUserToPerson.call(person: @person, user: @user)
      stamp_resolution(DECISION_LINK)
      @request.revoke! if @request.may_revoke?
    end

    def stamp_resolution(decision)
      @request.metadata = @request.metadata.merge(
        "resolution" => {
          "decision" => decision.to_s,
          "resolved_by_person_id" => @resolved_by&.id,
          "resolved_at" => Time.current.iso8601
        }.compact
      )
    end
  end
end
