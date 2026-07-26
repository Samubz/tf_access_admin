# frozen_string_literal: true

# Redirect helpers for PropertySections::* service outcomes
# (PropertySections::Result). Keeps the Inertia error contract uniform across the
# canonical section mutation channel (improve-property-sections §7.7).
module RespondsToSectionResult
  extend ActiveSupport::Concern

  private

  def respond_to_section_result(result, success_path:, error_path:)
    if result.invalid?
      redirect_to error_path, inertia: { errors: serialize_inertia_errors(result.section) }
    else
      redirect_to success_path
    end
  end
end
