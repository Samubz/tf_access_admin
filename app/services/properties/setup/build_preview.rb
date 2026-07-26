# frozen_string_literal: true

module Properties
  module Setup
    # Aggregates wizard summary data for review and confirmation steps.
    class BuildPreview
      def self.call(property:, actor: nil)
        new(property: property, actor: actor).call
      end

      def initialize(property:, actor: nil)
        @property = property
        @actor = actor
      end

      def call
        sections = visible_sections
        units = visible_units
        wizard = WizardState.read(@property)

        {
          property: property_summary,
          structure: structure_summary(sections, wizard),
          units: units_summary(units),
          counts: {
            sections: sections.count,
            units: units.count,
            **structure_level_counts(sections)
          },
          blocking_errors: blocking_errors(units),
          warnings: warnings(wizard),
          duplicates: [],
          omitted: []
        }
      end

      private

      # Excludes units whose section was soft-deleted. +Unit#property_section+
      # already returns nil for a soft-deleted parent (PropertySection's own
      # paranoid default scope applies to the eager-loaded preload query), but a
      # plain `@property.units.count` still counts the row itself, so section
      # membership must be checked explicitly (fix-wizard-summary-persisted-data).
      # Also excludes units that are effectively archived — their own status, or
      # their section's (self or nearest archived ancestor, capped at the
      # two-level hierarchy) — from the wizard specifically
      # (enable-wizard-editing-created-state).
      def visible_units
        deleted_section_ids = PropertySection.only_deleted
          .where(residential_property_id: @property.id)
          .pluck(:id)
        excluded_section_ids = deleted_section_ids | archived_section_ids
        scope = @property.units.includes(:property_section)
        scope = scope.where.not(property_section_id: excluded_section_ids) if excluded_section_ids.any?
        scope.where.not(status: UnitStatuses::ARCHIVED)
      end

      # Sections visible to the wizard: not soft-deleted (default scope) and not
      # effectively archived (self or parent archived).
      def visible_sections
        ids = archived_section_ids
        scope = @property.property_sections.includes(:parent)
        ids.any? ? scope.where.not(id: ids) : scope
      end

      # A section's own archived status, plus any root section's children when
      # the root is archived (the hierarchy is capped at two levels, so this
      # covers the full "self or nearest archived ancestor" rule without a
      # recursive query).
      def archived_section_ids
        return @archived_section_ids if defined?(@archived_section_ids)

        own_archived = @property.property_sections.where(status: SectionStatuses::ARCHIVED).pluck(:id)
        children_of_archived = own_archived.any? ? @property.property_sections.where(parent_id: own_archived).pluck(:id) : []
        @archived_section_ids = (own_archived + children_of_archived).uniq
      end

      # fix-automatic-unit-generation §8: structure counts are resolved from the
      # property's recommended +PropertyStructureFormat+ (top level + +units_in+
      # leaf), not from hardcoded tower/floor section types, so condominium/sector
      # structures report accurate, non-zero counts.
      #
      # +level_2+ is only populated for two-level formats. For a single-level
      # format the sole level *is* the leaf (+levels.first == units_in+), so
      # counting +units_in+ again would double-count the same sections; +level_2+
      # stays 0. Mirrors +GenerateStructurePreview.counts+.
      def structure_level_counts(sections)
        format = StructureFormatResolver.for(property_type: @property.property_type)
        return { level_1: 0, level_2: 0 } if format.nil?

        top_type = format.levels.first[:section_type]
        {
          level_1: sections.where(section_type: top_type).count,
          level_2: format.single_level? ? 0 : sections.where(section_type: format.units_in).count
        }
      end

      def property_summary
        {
          name: @property.name,
          property_type: @property.property_type,
          address_line: @property.address_line,
          city: @property.city,
          region: @property.region,
          country: @property.country
        }
      end

      # +include_units+ is always on so step 3 manual unit management can render
      # persisted units under their section without a second tree fetch
      # (add-manual-section-units). Step 2 consumers ignore the extra `units` key.
      #
      # Archived sections are pruned from the wizard's tree specifically (their
      # subtree comes with them, since an archived root's children already
      # report `effective_status: archived`); `TreeBuilder` itself is unchanged
      # and still shows archived sections (disabled) to non-wizard callers
      # (enable-wizard-editing-created-state).
      def structure_summary(sections, wizard)
        {
          mode: wizard[:structure_mode],
          tree: prune_archived(PropertySections::TreeBuilder.new(
            actor: @actor,
            property: @property,
            include_units: true
          ).tree)
        }
      rescue StandardError
        { mode: wizard[:structure_mode], tree: [] }
      end

      def prune_archived(nodes)
        nodes.reject { |node| node[:effective_status] == SectionStatuses::ARCHIVED }
          .map { |node| node.merge(children: prune_archived(node[:children] || [])) }
      end

      def units_summary(units)
        units.includes(property_section: :parent)
          .order(:identifier)
          .limit(4)
          .map { |unit| unit_preview_row(unit) }
      end

      def unit_preview_row(unit)
        section = unit.property_section
        tower = section&.parent

        {
          id: unit.id,
          code: unit.code,
          identifier: unit.identifier,
          unit_type: unit.unit_type,
          tower_name: tower&.name,
          floor_name: tower.present? ? section&.name : nil,
          section_name: section&.name,
          area_m2: unit.area_m2,
          orientation: unit.metadata["orientation"],
          bedrooms: unit.metadata["bedrooms"]
        }
      end

      def blocking_errors(units)
        errors = []
        if WizardState.structure_mode(@property) == "manual" && @property.property_sections.none?
          errors << I18n.t("frontend.admin.property_setup.step2.errors.manual_empty")
        end
        units_mode = WizardState.units_mode(@property)
        if units.none? && units_mode != "import" && units_mode != "automatic"
          errors << I18n.t("frontend.admin.property_setup.step3.errors.no_units")
        end
        errors
      end

      def warnings(_wizard)
        []
      end
    end
  end
end
