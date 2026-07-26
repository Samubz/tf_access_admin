# frozen_string_literal: true

module Properties
  module Setup
    # Builds paginated unit identifier previews from structure parameters.
    #
    # Delegates the "which units, with which identifiers, in which leaf"
    # calculation to the shared {UnitGenerationPlan}, so the preview shown here
    # matches exactly what {ApplyAutomaticUnits} persists
    # (fix-automatic-unit-generation §2).
    class GenerateUnitsPreview
      DEFAULT_PER_PAGE = 20

      def self.call(property:, params: {}, page: 1, per_page: DEFAULT_PER_PAGE)
        new(property: property, params: params, page: page, per_page: per_page).call
      end

      def initialize(property:, params:, page:, per_page:)
        @property = property
        @params = params.to_h.with_indifferent_access
        @page = [ page.to_i, 1 ].max
        @per_page = [ per_page.to_i, 1 ].max
      end

      def call
        rows = build_rows
        total = rows.size
        offset = (@page - 1) * @per_page
        page_rows = rows.slice(offset, @per_page) || []

        {
          rows: page_rows,
          total_units: total,
          pagination: {
            page: @page,
            per_page: @per_page,
            total: total,
            total_pages: (total.to_f / @per_page).ceil
          }
        }
      end

      private

      def build_rows
        UnitGenerationPlan.call(property: @property, format: format, params: @params).map do |row|
          leaf = row.property_section
          parent = leaf&.parent

          {
            tower: parent&.name,
            floor: leaf&.name,
            identifier: row.identifier
          }
        end
      end

      def format
        @format ||= StructureFormatResolver.for(property_type: @property.property_type)
      end
    end
  end
end
