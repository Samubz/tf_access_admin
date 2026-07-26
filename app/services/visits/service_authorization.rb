# frozen_string_literal: true

module Visits
  module ServiceAuthorization
    private

    def authorize_visit_action!(record, query)
      with_actor_context do
        policy = VisitPolicy.new(@actor, record)
        raise Pundit::NotAuthorizedError unless policy.public_send(query)
      end
    end

    def with_actor_context
      previous_user = Current.user
      previous_person = Current.person
      previous_profile = Current.authorization_grant_profile
      organization = ActsAsTenant.current_tenant

      Current.user = @actor
      Current.person = @actor.person_for(organization) if organization
      Current.authorization_grant_profile = nil

      yield
    ensure
      Current.user = previous_user
      Current.person = previous_person
      Current.authorization_grant_profile = previous_profile
    end
  end
end
