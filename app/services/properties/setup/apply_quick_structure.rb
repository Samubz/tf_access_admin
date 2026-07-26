# frozen_string_literal: true

module Properties
  module Setup
    # Persists quick-structure sections on a draft property.
    class ApplyQuickStructure < Base
      def initialize(actor:, property:, params:)
        super(actor: actor)
        @property = property
        @params = params.to_h.with_indifferent_access
      end

      def call
        authorize_setup_property!(@property)
        return Result.invalid(@property) unless @property.status == PropertyStatuses::DRAFT

        # fix-automatic-unit-generation §4a: regenerating the quick structure
        # destroys existing sections, but +destroy_all+ silently skips sections
        # whose +units+ block deletion (+restrict_with_error+) without raising or
        # rolling back. Guard explicitly before any destroy so generated units are
        # never orphaned or left half-regenerated.
        if @property.units.any?
          @property.errors.add(:base, :structure_regeneration_blocked_by_units)
          return Result.invalid(@property)
        end

        format = StructureFormatResolver.for(property_type: @property.property_type)
        preview = GenerateStructurePreview.call(params: @params, format: format, page: 1, per_page: 10_000)
        parent_map = {}

        ActiveRecord::Base.transaction do
          @property.property_sections.where.not(parent_id: nil).destroy_all
          @property.property_sections.where(parent_id: nil).destroy_all

          preview[:nodes].each do |node|
            if node[:depth] == 1
              result = PropertySections::Create.call(
                actor: @actor,
                property: @property,
                attributes: {
                  name: node[:name],
                  section_type: node[:section_type]
                }
              )
              raise ActiveRecord::Rollback unless result.success?

              parent_map[node[:id]] = result.section
            end
          end

          preview[:nodes].each do |node|
            next unless node[:depth] == 2

            parent = parent_map[node[:parent_id]]
            next if parent.nil?

            result = PropertySections::Create.call(
              actor: actor,
              property: @property,
              parent: parent,
              attributes: {
                name: node[:name],
                section_type: node[:section_type]
              }
            )
            raise ActiveRecord::Rollback unless result.success?
          end
        end

        WizardState.merge!(
          @property,
          structure_mode: "quick",
          quick_structure: @params,
          quick_structure_confirmed: true
        )
        @property.save!

        Result.success(@property)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::Rollback
        @property.errors.add(:base, :structure_apply_failed)
        Result.invalid(@property)
      end
    end
  end
end
