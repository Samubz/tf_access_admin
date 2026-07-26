# frozen_string_literal: true

# MVP contract for optional visit metadata: vehicle, check-in and check-out payloads.
module Visit::OperationalMetadata
  extend ActiveSupport::Concern

  VEHICLE_KEYS = %w[plate brand_model color].freeze
  CHECK_IN_KEYS = %w[access_point access_type vehicle_plate notes].freeze
  CHECK_OUT_KEYS = %w[access_point incident_type notes].freeze
  ROOT_KEYS = %w[vehicle check_in check_out].freeze

  class_methods do
    def sanitize_metadata(raw)
      source = raw.is_a?(Hash) ? raw : {}
      normalized = source.deep_stringify_keys

      {
        "vehicle" => sanitize_vehicle(normalized["vehicle"]),
        "check_in" => sanitize_section(normalized["check_in"], allowed_keys: CHECK_IN_KEYS),
        "check_out" => sanitize_section(normalized["check_out"], allowed_keys: CHECK_OUT_KEYS)
      }.compact_blank
    end

    def sanitize_vehicle(raw)
      sanitize_section(raw, allowed_keys: VEHICLE_KEYS)
    end

    def sanitize_check_in(raw)
      sanitize_section(raw, allowed_keys: CHECK_IN_KEYS)
    end

    def sanitize_check_out(raw)
      sanitize_section(raw, allowed_keys: CHECK_OUT_KEYS)
    end

    private

    def sanitize_section(raw, allowed_keys:)
      return nil unless raw.is_a?(Hash)

      raw.deep_stringify_keys.slice(*allowed_keys).each_with_object({}) do |(key, value), result|
        next if value.blank?

        result[key] = value.to_s.strip
      end.presence
    end
  end

  def merge_vehicle_metadata!(raw)
    vehicle = self.class.sanitize_vehicle(raw)
    return self if vehicle.blank?

    self.metadata = metadata.merge("vehicle" => vehicle)
    self
  end

  def merge_check_in_metadata!(raw)
    check_in = self.class.sanitize_check_in(raw)
    return self if check_in.blank?

    self.metadata = metadata.merge("check_in" => check_in)
    self
  end

  def merge_check_out_metadata!(raw)
    check_out = self.class.sanitize_check_out(raw)
    return self if check_out.blank?

    self.metadata = metadata.merge("check_out" => check_out)
    self
  end

  def vehicle_metadata
    metadata.fetch("vehicle", {})
  end

  def check_in_metadata
    metadata.fetch("check_in", {})
  end

  def check_out_metadata
    metadata.fetch("check_out", {})
  end
end
