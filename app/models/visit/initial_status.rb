# frozen_string_literal: true

# Resolves the backend initial visit status from actor capabilities.
# Client-requested status is ignored unless the actor may authorize directly.
module Visit::InitialStatus
  module_function

  def resolve(actor:, unit:, requested_status: nil)
    return VisitStatuses::PENDING if actor.blank? || unit.blank?

    resolver = Authorization::Resolver.new(
      user: actor,
      organization: unit.organization,
      property: unit.residential_property,
      unit: unit
    )

    can_authorize_directly =
      resolver.allowed?(:manage_visits) || resolver.allowed?(:authorize_visits)

    if requested_status == VisitStatuses::AUTHORIZED && can_authorize_directly
      VisitStatuses::AUTHORIZED
    else
      VisitStatuses::PENDING
    end
  end
end
