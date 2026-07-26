# frozen_string_literal: true

module Properties
  module Setup
    # Builds paginated preview nodes for quick structure generation.
    #
    # When a +PropertyStructureFormat+ is provided, nodes are generated from the
    # format's levels (section_type, prefix and suffix_type per level). Without a
    # format it falls back to the legacy tower/floor behavior for backward
    # compatibility.
    class GenerateStructurePreview
      DEFAULT_PER_PAGE = 20

      def self.call(params:, format: nil, page: 1, per_page: DEFAULT_PER_PAGE)
        new(params: params, format: format, page: page, per_page: per_page).call
      end

      def initialize(params:, format:, page:, per_page:)
        @params = params.to_h.with_indifferent_access
        @format = format
        @page = [ page.to_i, 1 ].max
        @per_page = [ per_page.to_i, 1 ].max
      end

      def call
        nodes = @format ? format_nodes : legacy_nodes
        paginate(nodes)
      end

      private

      # --- Format-aware generation -------------------------------------------

      def format_nodes
        levels = effective_levels
        return [] if levels.empty?

        if levels.size == 1
          single_level_nodes(levels.first)
        else
          two_level_nodes(levels.first, levels.last)
        end
      end

      # Honors the building "no towers" case: when +skip_top_level+ is set and the
      # format has 2 levels, only the leaf level is generated as top-level sections.
      def effective_levels
        levels = @format.levels
        return [ levels.last ] if levels.size == 2 && skip_top_level?

        levels
      end

      def skip_top_level?
        ActiveModel::Type::Boolean.new.cast(@params[:skip_top_level])
      end

      def single_level_nodes(level)
        count = level_count(1)
        prefix = level_prefix(1, level)

        Array.new(count) do |index|
          {
            id: "level1-#{index}",
            name: section_name(prefix, level[:suffix_type], index),
            section_type: level[:section_type],
            depth: 1
          }
        end
      end

      def two_level_nodes(top_level, leaf_level)
        top_count = level_count(1)
        leaf_count = level_count(2)
        top_prefix = level_prefix(1, top_level)
        leaf_prefix = level_prefix(2, leaf_level)

        nodes = []
        top_count.times do |top_index|
          top_id = "level1-#{top_index}"
          nodes << {
            id: top_id,
            name: section_name(top_prefix, top_level[:suffix_type], top_index),
            section_type: top_level[:section_type],
            depth: 1
          }

          leaf_count.times do |leaf_index|
            nodes << {
              id: "#{top_id}-level2-#{leaf_index}",
              parent_id: top_id,
              name: section_name(leaf_prefix, leaf_level[:suffix_type], leaf_index),
              section_type: leaf_level[:section_type],
              depth: 2
            }
          end
        end
        nodes
      end

      def level_count(position)
        @params.fetch("level_#{position}_count", 1).to_i
      end

      def level_prefix(position, level)
        @params.fetch("level_#{position}_prefix", default_prefix(level[:section_type])).to_s
      end

      def default_prefix(section_type)
        I18n.t(
          "admin.property_setup.structure_formats.section_types.#{section_type}",
          default: section_type.to_s.capitalize
        )
      end

      def section_name(prefix, suffix_type, index)
        SectionNameSequence.name(prefix: prefix, suffix_type: suffix_type, index: index)
      end

      # --- Legacy tower/floor generation -------------------------------------

      def legacy_nodes
        towers = @params.fetch(:towers, 1).to_i
        floors = @params.fetch(:floors_per_tower, 1).to_i
        tower_prefix = @params.fetch(:tower_prefix, "Torre").to_s
        floor_prefix = @params.fetch(:floor_prefix, "Piso").to_s

        nodes = []
        towers.times do |tower_index|
          nodes << {
            id: "tower-#{tower_index}",
            name: "#{tower_prefix} #{("A".ord + tower_index).chr}",
            section_type: SectionTypes::TOWER,
            depth: 1
          }

          floors.times do |floor_index|
            nodes << {
              id: "tower-#{tower_index}-floor-#{floor_index + 1}",
              parent_id: "tower-#{tower_index}",
              name: "#{floor_prefix} #{floor_index + 1}",
              section_type: SectionTypes::FLOOR,
              depth: 2
            }
          end
        end
        nodes
      end

      # --- Pagination ---------------------------------------------------------

      def paginate(nodes)
        total = nodes.size
        offset = (@page - 1) * @per_page
        page_nodes = nodes.slice(offset, @per_page) || []

        {
          nodes: page_nodes,
          counts: counts(nodes),
          pagination: {
            page: @page,
            per_page: @per_page,
            total: total,
            total_pages: (total.to_f / @per_page).ceil
          }
        }
      end

      def counts(nodes)
        {
          level_1: nodes.count { |node| node[:depth] == 1 },
          level_2: nodes.count { |node| node[:depth] == 2 },
          sections: nodes.size
        }
      end
    end
  end
end
