# frozen_string_literal: true

module Residents
  # Creates an authorized visit from a resident-initiated private API request (4.x).
  #
  # Wraps visitor resolution (3.x) and visit creation in a single atomic
  # transaction so that a failure in any step leaves no partial records.
  #
  # Delegates to the canonical Visits::Create service, which handles:
  #   4.1 — associates the visit with the validated unit and resolved visitor
  #   4.3 — residential_property_id and property_section_id are derived from unit
  #           via Visit#denormalize_location_from_unit (before_validation callback)
  #   4.4 — requests VisitStatuses::AUTHORIZED; Visit::InitialStatus.resolve grants
  #           it only when the actor holds authorize_visits — already verified in 2.x
  #   4.5 — created_by_id and authorized_by_id are stamped from @actor by
  #           Visit::StateMachine#assign_initial_status! + #stamp_authorization
  #   4.6 — authorized_at is recorded by #stamp_authorization; the CREATED functional
  #           event is persisted by Visits::RecordEvent inside Visits::Create
  #   4.7 — outer transaction wraps visitor resolution + Visits::Create (which
  #           has its own inner transaction — Rails uses savepoints)
  class CreateAuthorizedVisit
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(unit:, visitor_params:, scheduled_at:, actor:)
      @unit           = unit
      @visitor_params = visitor_params
      @scheduled_at   = scheduled_at
      @actor          = actor
    end

    # Returns the persisted Visit in authorized status.
    def call
      ActiveRecord::Base.transaction do
        visitor_person = Residents::ResolveVisitorPerson.call(
          organization: @unit.organization,
          visitor_params: @visitor_params
        )

        Visits::Create.call(
          unit: @unit,
          visit_params: {
            visitor_person_id: visitor_person.id,
            scheduled_at:      @scheduled_at,
            visit_type:        VisitTypes::GUEST
          },
          actor:            @actor,
          requested_status: VisitStatuses::AUTHORIZED
        )
      end
    end
  end
end
