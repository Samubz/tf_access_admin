# frozen_string_literal: true

module Visits
  module OperationalMetadataParams
    class InvalidMetadataError < StandardError; end

    module_function

    def check_in(access_point: nil, access_type: nil, vehicle_plate: nil, notes: nil, raw: {})
      payload = raw.to_h.deep_symbolize_keys
      payload[:access_point] = access_point if access_point.present?
      payload[:access_type] = access_type if access_type.present?
      payload[:vehicle_plate] = vehicle_plate if vehicle_plate.present?
      payload[:notes] = notes if notes.present?

      sanitized = Visit.sanitize_check_in(payload)
      validate_access_type!(sanitized&.fetch("access_type", nil))
      sanitized || {}
    end

    def check_out(access_point: nil, incident_type: nil, notes: nil, raw: {})
      payload = raw.to_h.deep_symbolize_keys
      payload[:access_point] = access_point if access_point.present?
      payload[:incident_type] = incident_type if incident_type.present?
      payload[:notes] = notes if notes.present?

      sanitized = Visit.sanitize_check_out(payload)
      validate_incident_type!(sanitized&.fetch("incident_type", nil))
      sanitized || {}
    end

    def validate_access_type!(value)
      return if value.blank?
      return if VisitAccessTypes::ALL.include?(value)

      raise InvalidMetadataError, I18n.t("frontend.admin.visits.validations.invalid_access_type")
    end

    def validate_incident_type!(value)
      return if value.blank?
      return if VisitIncidentTypes::ALL.include?(value)

      raise InvalidMetadataError, I18n.t("frontend.admin.visits.validations.invalid_incident_type")
    end
  end
end
