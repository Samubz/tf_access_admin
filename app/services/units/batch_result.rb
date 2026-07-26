# frozen_string_literal: true

module Units
  # Outcome of a batch unit creation (add-manual-section-units).
  #
  # - +:success+ — every unit in the batch persisted; +units+ holds them.
  # - +:invalid+ — the transaction rolled back; +unit+ carries the first failing
  #   node (or a blank placeholder) with its +errors+ so the caller can surface
  #   field errors.
  BatchResult = Data.define(:status, :units, :unit) do
    def self.success(units) = new(status: :success, units: units, unit: nil)
    def self.invalid(unit) = new(status: :invalid, units: [], unit: unit)

    def success? = status == :success
    def invalid? = status == :invalid

    def errors = unit&.errors
  end
end
