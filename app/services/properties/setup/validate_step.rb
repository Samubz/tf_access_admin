# frozen_string_literal: true

module Properties
  module Setup
    # Validates wizard step input before advancing.
    class ValidateStep < Base
      STEP_1_REQUIRED = %i[name property_type].freeze

      def initialize(property:, step:, attributes: {})
        @property = property
        @step = step.to_i
        @attributes = attributes.to_h.symbolize_keys
      end

      def call
        case @step
        when 1 then validate_step_1
        when 2 then validate_step_2
        when 3 then validate_step_3
        when 4 then validate_step_4
        else
          { valid: false, errors: { base: [ I18n.t("frontend.admin.property_setup.errors.invalid_step") ] } }
        end
      end

      private

      def validate_step_1
        draft = ResidentialProperty.new(descriptive_attributes(@attributes))
        draft.organization = @property&.organization || ActsAsTenant.current_tenant
        draft.status = PropertyStatuses::DRAFT
        draft.assign_attributes(descriptive_attributes(@attributes))

        unless address_present?(draft)
          draft.errors.add(:address_line, :blank)
        end

        STEP_1_REQUIRED.each do |field|
          draft.errors.add(field, :blank) if draft.public_send(field).blank?
        end

        build_result(draft)
      end

      def validate_step_2
        mode = @attributes[:structure_mode].presence || WizardState.structure_mode(@property)
        errors = {}

        case mode
        when "none"
          { valid: true, errors: {} }
        when "manual"
          if @property.property_sections.none?
            errors[:structure] = [ I18n.t("frontend.admin.property_setup.step2.errors.manual_empty") ]
          end
          { valid: errors.empty?, errors: errors }
        when "quick"
          unless @attributes[:quick_structure_confirmed] || WizardState.read(@property)[:quick_structure_confirmed]
            errors[:quick_structure] = [
              I18n.t("frontend.admin.property_setup.step2.errors.quick_not_confirmed")
            ]
          end
          { valid: errors.empty?, errors: errors }
        else
          errors[:structure_mode] = [ I18n.t("frontend.admin.property_setup.step2.errors.mode_required") ]
          { valid: false, errors: errors }
        end
      end

      def validate_step_3
        mode = @attributes[:units_mode].presence || WizardState.units_mode(@property)
        errors = {}

        if mode.blank?
          errors[:units_mode] = [ I18n.t("frontend.admin.property_setup.step3.errors.mode_required") ]
          return { valid: false, errors: errors }
        end

        if @property.units.none? && mode != "import" && mode != "automatic"
          errors[:units] = [ I18n.t("frontend.admin.property_setup.step3.errors.no_units") ]
        end

        if mode == "automatic"
          format = StructureFormatResolver.for(property_type: @property.property_type)
          if format && @property.property_sections.where(section_type: format.units_in).none?
            errors[:structure] = [ I18n.t("frontend.admin.property_setup.step3.errors.no_leaf_sections") ]
          end
        end

        { valid: errors.empty?, errors: errors }
      end

      def validate_step_4
        summary = BuildPreview.call(property: @property)
        blocking = summary[:blocking_errors] || []

        if blocking.any?
          { valid: false, errors: { summary: blocking } }
        else
          { valid: true, errors: {} }
        end
      end

      def build_result(record)
        if record.errors.empty?
          { valid: true, errors: {} }
        else
          {
            valid: false,
            errors: record.errors.to_hash(true).transform_values { |messages| Array(messages) }
          }
        end
      end
    end
  end
end
