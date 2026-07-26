# frozen_string_literal: true

module Units
  # Creates N units under a single eligible section in one transaction, reusing
  # {Units::Create} per unit so every `Unit` validation, tenant scope and code
  # derivation rule still applies (add-manual-section-units).
  #
  # Identifiers come from {Units::IdentifierSequence}: generated from
  # +prefix+/+suffix_type+/+count+ (multiple mode), skipping units in the section
  # whose normalized identifier is already taken. All-or-nothing: any single
  # failure rolls back the whole batch and returns the failing unit with its
  # errors.
  class CreateBatch < Base
    def initialize(actor:, property:, section_id:, attributes: {}, prefix:, suffix_type: :letter, count:)
      super(actor: actor)
      @property = property
      @section_id = section_id
      @attributes = attributes.to_h.symbolize_keys
      @prefix = prefix
      @suffix_type = suffix_type
      @count = count
    end

    def call
      authorize_manage_units!(@property)

      section = resolve_required_section
      return BatchResult.invalid(section_invalid_unit) if section == :invalid

      identifiers = resolved_identifiers(section)
      return BatchResult.invalid(insufficient_unit) if identifiers.size < @count.to_i

      created = []
      ActiveRecord::Base.transaction do
        identifiers.each do |identifier|
          result = Units::Create.call(
            actor: actor,
            property: @property,
            section_id: section.id,
            attributes: @attributes.merge(identifier: identifier)
          )

          unless result.success?
            @failed_unit = result.unit
            raise ActiveRecord::Rollback
          end

          created << result.unit
        end
      end

      return BatchResult.invalid(@failed_unit) if @failed_unit

      BatchResult.success(created)
    end

    private

    def resolve_required_section
      id = @section_id.presence
      return :invalid if id.nil?

      @property.property_sections.find_by(id: id) || :invalid
    end

    def resolved_identifiers(section)
      return [] if @prefix.blank? || @count.to_i <= 0

      Units::IdentifierSequence.available_identifiers(
        prefix: @prefix,
        suffix_type: @suffix_type,
        count: @count,
        taken_normalized_identifiers: sibling_normalized_identifiers(section)
      )
    end

    def sibling_normalized_identifiers(section)
      @property.units.where(property_section_id: section.id).pluck(:normalized_identifier)
    end

    def blank_unit
      unit = Unit.new(unit_type: @attributes[:unit_type])
      unit.residential_property = @property
      unit
    end

    def section_invalid_unit
      unit = blank_unit
      unit.errors.add(:property_section_id, t_validation("section_invalid"))
      unit
    end

    def insufficient_unit
      unit = blank_unit
      unit.errors.add(:base, :insufficient_available_identifiers, count: @count.to_i)
      unit
    end
  end
end
