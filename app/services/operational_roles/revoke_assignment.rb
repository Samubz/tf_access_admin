# frozen_string_literal: true

module OperationalRoles
  # Revokes (deactivates) an active +StaffAssignment+.
  #
  # Sets +status+ to +STATUS_INACTIVE+ and +ends_at+ to today if not already
  # past. An audit record is produced via +audited+. Capabilities derived from
  # this assignment are no longer granted after revocation.
  #
  # == Input contract
  #   actor:      User — operator performing the revocation (for audit)
  #   assignment: StaffAssignment — the assignment to revoke
  #
  # == Output contract
  #   { success: Boolean, assignment: StaffAssignment, errors: Array<String> }
  class RevokeAssignment
    def initialize(actor:, assignment:)
      @actor = actor
      @assignment = assignment
    end

    def call
      errors = validate
      return failure(errors) if errors.any?

      assignment.update!(
        status: StaffAssignment::STATUS_INACTIVE,
        ends_at: [ assignment.ends_at, Date.current ].compact.min
      )

      { success: true, assignment: assignment, errors: [] }
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    attr_reader :actor, :assignment

    def validate
      errors = []
      errors << "Assignment is already inactive" if assignment.status == StaffAssignment::STATUS_INACTIVE
      errors
    end

    def failure(errors)
      { success: false, assignment: assignment, errors: Array(errors) }
    end
  end
end
