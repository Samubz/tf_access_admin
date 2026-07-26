# frozen_string_literal: true

module Visits
  class RecordEvent
    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(visit:, event_type:, to_status:, actor:, from_status: nil, occurred_at: Time.zone.now, notes: nil, metadata: {})
      @visit = visit
      @event_type = event_type
      @from_status = from_status
      @to_status = to_status
      @actor = actor
      @occurred_at = occurred_at
      @notes = notes
      @metadata = metadata
    end

    def call
      @visit.visit_status_histories.create!(
        organization: @visit.organization,
        event_type: @event_type,
        from_status: @from_status,
        to_status: @to_status,
        actor_user: @actor,
        occurred_at: @occurred_at,
        notes: @notes,
        metadata: @metadata
      )
    end
  end
end
