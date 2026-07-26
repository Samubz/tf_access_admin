# frozen_string_literal: true

module Units
  # Structured outcome shared by the unit lifecycle services so controllers
  # and the UI consume a uniform contract (improve-units-foundation §2.10).
  #
  # - +:success+   — the operation persisted the unit.
  # - +:invalid+   — domain/validation failure; +unit.errors+ carries field errors.
  # - +:noop+      — nothing to do (e.g. archiving an already-archived unit).
  # - +:conflict+  — concurrent uniqueness violation mapped to domain errors.
  # - unauthorized — propagated via Pundit::NotAuthorizedError (not a Result status).
  Result = Data.define(:status, :unit) do
    def self.success(unit) = new(status: :success, unit: unit)
    def self.invalid(unit) = new(status: :invalid, unit: unit)
    def self.noop(unit)    = new(status: :noop, unit: unit)
    def self.conflict(unit) = new(status: :conflict, unit: unit)

    def success?   = %i[success noop].include?(status)
    def invalid?   = status == :invalid
    def noop?      = status == :noop
    def conflict?  = status == :conflict

    def errors = unit&.errors
  end
end
