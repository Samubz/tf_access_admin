# frozen_string_literal: true

module Units
  # Applies descriptive changes and operational status transitions
  # (improve-units-foundation §2.3).
  class Update < Base
    def initialize(actor:, unit:, attributes: {})
      super(actor: actor)
      @unit       = unit
      @attributes = attributes.to_h.symbolize_keys
    end

    def call
      authorize_manage_units!(@unit.residential_property)

      return Result.invalid(@unit) unless reject_inoperative_property!(@unit)

      @unit.assign_attributes(descriptive_attributes(@attributes))
      return Result.invalid(@unit) if archive_via_status_requested?
      return Result.invalid(@unit) if invalid_status_transition?
      return Result.invalid(@unit) if identifier_code_conflict?

      apply_status

      save_unit(@unit)
    end

    private

    # Regenerating the derived code on a supported identifier edit must reject on
    # collision rather than silently suffix, unlike creation (hierarchical-code-
    # generation §Unit code, add-manual-section-units). Only recompute when the
    # identifier actually changed so an edit that leaves it untouched keeps its
    # existing code.
    def identifier_code_conflict?
      return false unless @unit.identifier_changed?

      candidate = regenerated_code
      return false if candidate.blank?

      if code_taken?(candidate)
        @unit.errors.add(:identifier, t_validation("code_conflict"))
        return true
      end

      @unit.code = candidate
      false
    end

    # Uses the identifier being submitted rather than `normalized_identifier`,
    # which is only recomputed by the `before_validation` callback on save and
    # would still read the previous value here.
    def regenerated_code
      segment = Units::NormalizeIdentifier.call(@unit.identifier)&.normalized_identifier
      return nil if segment.blank?

      prefix = @unit.property_section&.code.presence || @unit.residential_property&.code
      [ prefix, segment ].reject(&:blank?).join("-").presence
    end

    def code_taken?(candidate)
      ::Unit.where(
        residential_property_id: @unit.residential_property_id,
        property_section_id: @unit.property_section_id,
        code: candidate
      ).where.not(id: @unit.id).exists?
    end

    def archive_via_status_requested?
      return false unless @attributes.key?(:status)
      return false unless @attributes[:status].to_s.strip.downcase == UnitStatuses::ARCHIVED

      @unit.errors.add(:status, :archive_requires_service)
      true
    end

    def invalid_status_transition?
      return false unless @attributes.key?(:status)

      requested = @attributes[:status].to_s.strip.downcase.presence
      return false if requested.nil?
      return false if UnitStatuses::OPERATIONAL.include?(requested)

      @unit.errors.add(:status, :transition_not_allowed)
      true
    end

    def apply_status
      return unless @attributes.key?(:status)

      requested = @attributes[:status].to_s.strip.downcase.presence
      @unit.status = requested if requested
    end
  end
end
