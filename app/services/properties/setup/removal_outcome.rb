# frozen_string_literal: true

module Properties
  module Setup
    # Structured outcome for wizard section/unit removal, distinct from the
    # per-record Result types because a removal may resolve to either a
    # soft-delete or an archive, or need explicit confirmation before either
    # happens (enable-wizard-editing-created-state).
    RemovalOutcome = Data.define(:status, :record) do
      def self.removed(record) = new(status: :removed, record: record)
      def self.archived(record) = new(status: :archived, record: record)
      def self.needs_confirmation(record) = new(status: :needs_confirmation, record: record)
      def self.invalid(record) = new(status: :invalid, record: record)

      def success? = %i[removed archived].include?(status)
      def needs_confirmation? = status == :needs_confirmation
      def invalid? = status == :invalid
      def errors = record&.errors
    end
  end
end
