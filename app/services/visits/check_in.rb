# frozen_string_literal: true

module Visits
  class CheckIn
    include ServiceAuthorization

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(visit:, actor:, access_point: nil, access_type: nil, vehicle_plate: nil, notes: nil,
                   check_in_metadata: {})
      @visit = visit
      @actor = actor
      @notes = notes
      @check_in_metadata = OperationalMetadataParams.check_in(
        access_point: access_point,
        access_type: access_type,
        vehicle_plate: vehicle_plate,
        raw: check_in_metadata
      )
    end

    def call
      authorize_visit_action!(@visit, :check_in?)

      # 3.7 — with_lock issues SELECT FOR UPDATE and wraps the block in a
      # transaction (savepoint when nested). Two concurrent check-in requests
      # on the same visit will queue on the row lock; the second will find
      # status = checked_in after the reload and AASM will raise InvalidTransition.
      @visit.with_lock do
        from_status = @visit.status
        @visit.merge_check_in_metadata!(@check_in_metadata) if @check_in_metadata.present?
        @visit.check_in!(@actor)
        @visit.save!

        RecordEvent.call(
          visit: @visit,
          event_type: VisitEventTypes::CHECKED_IN,
          from_status: from_status,
          to_status: @visit.status,
          actor: @actor,
          notes: @notes,
          metadata: { "check_in" => @visit.check_in_metadata }.compact_blank
        )
      end

      # 3.9 — post-commit domain event with tenant-safe IDs only.
      # Delivery (job, channel, content) is out of scope; subscribers attach here.
      emit_checked_in_event

      @visit
    end

    private

    # 3.9 — Emits visit.checked_in after a successful commit so future
    # notification subscribers can react without coupling to the service.
    def emit_checked_in_event
      ActiveSupport::Notifications.instrument("visit.checked_in",
        organization_id: @visit.organization_id,
        visit_id:        @visit.id,
        unit_id:         @visit.unit_id,
        checked_in_by_id: @visit.checked_in_by_id
      )
    end
  end
end
