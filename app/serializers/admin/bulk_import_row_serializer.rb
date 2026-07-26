# frozen_string_literal: true

class Admin::BulkImportRowSerializer < ActiveModel::Serializer
  attributes :id,
             :row_number,
             :validation_status,
             :import_status,
             :onboarding_classification,
             :target_record_type,
             :validation_errors,
             :validation_warnings,
             :normalized_payload,
             :group_key

  def validation_errors
    Array(object.validation_errors)
  end

  def validation_warnings
    Array(object.validation_warnings)
  end

  def normalized_payload
    object.normalized_payload.deep_stringify_keys
  end
end
