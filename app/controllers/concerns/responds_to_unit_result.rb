# frozen_string_literal: true

# Redirect helpers for Units::* service outcomes (Units::Result). Keeps the
# Inertia error contract uniform across the canonical unit mutation channel
# (improve-units-foundation §6.5).
module RespondsToUnitResult
  extend ActiveSupport::Concern

  private

  def respond_to_unit_result(result, success_path:, error_path:)
    if result.invalid? || result.conflict?
      redirect_to error_path, inertia: { errors: serialize_inertia_errors(result.unit) }
    else
      redirect_to success_path
    end
  end
end
