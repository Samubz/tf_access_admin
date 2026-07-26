# frozen_string_literal: true

module PropertySections
  # Outcome of a batch section creation (wizard-manual-structure-builder).
  #
  # - +:success+ — every section in the batch persisted; +sections+ holds them.
  # - +:invalid+ — the transaction rolled back; +section+ carries the first
  #   failing node with its +errors+ so the caller can surface field errors.
  BatchResult = Data.define(:status, :sections, :section) do
    def self.success(sections) = new(status: :success, sections: sections, section: nil)
    def self.invalid(section) = new(status: :invalid, sections: [], section: section)

    def success? = status == :success
    def invalid? = status == :invalid

    def errors = section&.errors
  end
end
