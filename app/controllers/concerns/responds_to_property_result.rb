# frozen_string_literal: true

# Redirect helpers for Properties::* service outcomes (Properties::Result).
module RespondsToPropertyResult
  extend ActiveSupport::Concern

  private

  def respond_to_property_result(result, success_path:, error_path:)
    if result.invalid?
      redirect_to error_path, inertia: { errors: serialize_inertia_errors(result.property) }
    else
      redirect_to success_path
    end
  end
end
