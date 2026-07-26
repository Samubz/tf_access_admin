# frozen_string_literal: true

module Properties
  # Structured outcome shared by the property lifecycle services so controllers
  # and the UI consume a uniform contract instead of bare booleans or raised
  # validation errors (improve-property-foundation §3.9).
  #
  # - +:success+ — the operation persisted the property.
  # - +:invalid+ — domain/validation failure; +property.errors+ carries field errors.
  # - +:noop+    — nothing to do (e.g. archiving an already-archived property); still a success.
  Result = Data.define(:status, :property) do
    def self.success(property) = new(status: :success, property: property)
    def self.invalid(property) = new(status: :invalid, property: property)
    def self.noop(property) = new(status: :noop, property: property)

    def success? = status != :invalid
    def invalid? = status == :invalid
    def noop? = status == :noop

    def errors = property&.errors
  end
end
