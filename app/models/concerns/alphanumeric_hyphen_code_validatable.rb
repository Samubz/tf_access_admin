# frozen_string_literal: true

# Validates code-like attributes and normalizes unit identifiers.
module AlphanumericHyphenCodeValidatable
  extend ActiveSupport::Concern

  STRICT_FORMAT = /\A[a-zA-Z0-9-]+\z/
  # Human identifiers accept Unicode letters/numbers (e.g. "Área 4"); the
  # transliterating slug (`DomainCodes::Slug`) folds them to ASCII for
  # `normalized_identifier` and derived codes (hierarchical-code-generation).
  IDENTIFIER_FORMAT = /\A[\p{L}\p{N}\s-]+\z/

  class_methods do
    def validates_alphanumeric_hyphen_code(*attributes, allow_whitespace: false)
      format = allow_whitespace ? IDENTIFIER_FORMAT : STRICT_FORMAT
      i18n_key = allow_whitespace ? "identifier_format_invalid" : "alphanumeric_hyphen_code_invalid"

      attributes.each do |attribute|
        method_name = :"validate_#{attribute}_alphanumeric_hyphen_code_format"

        define_method(method_name) do
          value = public_send(attribute)
          return if value.blank?
          return if format.match?(value)

          errors.add(attribute, I18n.t("frontend.admin.validations.#{i18n_key}"))
        end

        private method_name
        validate method_name
      end
    end
  end

  def self.normalize_identifier(value)
    value.to_s.strip.downcase.gsub(/\s+/, "-")
  end
end
