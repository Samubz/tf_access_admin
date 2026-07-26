# frozen_string_literal: true

module Visits
  class CheckOut
    include ServiceAuthorization

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(visit:, actor:, access_point: nil, incident_type: nil, notes: nil, check_out_metadata: {})
      @visit = visit
      @actor = actor
      @notes = notes
      @check_out_metadata = OperationalMetadataParams.check_out(
        access_point: access_point,
        incident_type: incident_type,
        raw: check_out_metadata
      )
    end

    def call
      authorize_visit_action!(@visit, :check_out?)

      # 4.8 — with_lock issues SELECT FOR UPDATE and wraps the block in a
      # transaction. Two concurrent check-out requests on the same visit queue
      # on the row lock; the second reloads status = checked_out and AASM raises
      # InvalidTransition, preventing a duplicate exit.
      @visit.with_lock do
        from_status = @visit.status
        @visit.merge_check_out_metadata!(@check_out_metadata) if @check_out_metadata.present?
        @visit.check_out!(@actor)
        @visit.save!

        RecordEvent.call(
          visit: @visit,
          event_type: VisitEventTypes::CHECKED_OUT,
          from_status: from_status,
          to_status: @visit.status,
          actor: @actor,
          notes: @notes,
          metadata: { "check_out" => @visit.check_out_metadata }.compact_blank
        )
      end

      @visit
    end
  end
end
