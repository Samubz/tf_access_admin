# frozen_string_literal: true

module Visits
  class Create
    include ServiceAuthorization

    VISIT_ASSIGNMENT_KEYS = %i[
      visitor_person_id scheduled_at valid_from valid_until
      visit_type notes metadata
    ].freeze

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(unit:, visit_params:, actor:, requested_status: nil)
      @unit = unit
      @visit_params = visit_params.to_h.symbolize_keys
      @actor = actor
      @requested_status = requested_status
    end

    def call
      visit = build_visit
      authorize_visit_action!(visit, :create?)

      ActiveRecord::Base.transaction do
        visit.assign_initial_status!(actor: @actor, requested_status: @requested_status)
        visit.save!

        RecordEvent.call(
          visit: visit,
          event_type: VisitEventTypes::CREATED,
          from_status: nil,
          to_status: visit.status,
          actor: @actor
        )

        visit
      end.tap do |created_visit|
        # Outside the transaction: a notification failure must never roll back
        # the created visit (design.md Decision 5).
        Notifications::CreateForVisit.call(visit: created_visit)
      end
    end

    private

    def build_visit
      visitor = @unit.organization.people.find(@visit_params.fetch(:visitor_person_id))

      Visit.new(
        organization: @unit.organization,
        unit: @unit,
        visitor_person: visitor,
        scheduled_at: @visit_params[:scheduled_at],
        valid_from: @visit_params[:valid_from],
        valid_until: @visit_params[:valid_until],
        visit_type: @visit_params[:visit_type],
        notes: @visit_params[:notes],
        metadata: Visit.sanitize_metadata(@visit_params[:metadata] || {})
      )
    end
  end
end
