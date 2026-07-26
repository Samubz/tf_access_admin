# frozen_string_literal: true

module Units
  # Whether a unit has any real operational history that must not be silently
  # soft-deleted (enable-wizard-editing-created-state).
  class HasOperationalHistory
    def self.call(unit)
      unit.unit_ownerships.exists? ||
        unit.lease_contracts.exists? ||
        unit.unit_occupancies.exists? ||
        unit.visits.exists?
    end
  end
end
