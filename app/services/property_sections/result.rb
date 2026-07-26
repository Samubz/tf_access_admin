# frozen_string_literal: true

module PropertySections
  # Structured outcome shared by the section lifecycle services so controllers
  # and the UI consume a uniform contract (improve-property-sections §4.8).
  #
  # - +:success+ — the operation persisted the section.
  # - +:invalid+ — domain/validation failure; +section.errors+ carries field errors.
  # - +:noop+    — nothing to do (e.g. archiving an already-archived section).
  Result = Data.define(:status, :section) do
    def self.success(section) = new(status: :success, section: section)
    def self.invalid(section) = new(status: :invalid, section: section)
    def self.noop(section) = new(status: :noop, section: section)

    def success? = status != :invalid
    def invalid? = status == :invalid
    def noop? = status == :noop

    def errors = section&.errors
  end
end
