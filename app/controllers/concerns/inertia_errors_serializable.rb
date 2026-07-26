# frozen_string_literal: true

# Normalizes ActiveModel errors into the Inertia errors prop contract.
module InertiaErrorsSerializable
  extend ActiveSupport::Concern

  private

  def serialize_inertia_errors(record, full_messages: true)
    record.errors.to_hash(full_messages).transform_values { |messages| Array(messages) }
  end
end
