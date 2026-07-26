# frozen_string_literal: true

module PropertySections
  # Property-scoped, read-only tree presenter for property sections
  # (improve-property-sections §5).
  #
  # Unlike the legacy +PropertySection::TreeBuilder+, this builder never trusts an
  # arbitrary collection: it loads sections itself from a single authorized
  # property, enforcing tenant/property scope (§5.1). It produces a stable DTO for
  # Inertia/Vue (§5.11) limited to the two-level domain (root section + subsection),
  # with depth, path, effective status and backend-driven permissions per node.
  class TreeBuilder
    # Maximum hierarchy depth the domain allows: root (1) + subsection (2).
    MAX_DEPTH = 2

    # Status precedence reused from the hierarchy concern: most restrictive wins.
    STATUS_SEVERITY = PropertySectionHierarchy::STATUS_SEVERITY

    def initialize(actor:, property:, include_units: false, include_archived: false)
      @actor = actor
      @property = property
      @include_units = include_units
      @include_archived = include_archived
    end

    # Full DTO consumed by the structure page (§5.11).
    def as_json
      {
        tree: tree,
        parent_options: parent_options
      }
    end

    # Ordered forest of root nodes, each carrying its subsections (§5.2).
    def tree
      @tree ||= build_nodes(roots, depth: 1, path: [], inherited_status: @property.status)
    end

    # Valid parents for create/move: only root sections; never subsections, so a
    # third level can never be requested (§5.8). The empty/"no parent" option is a
    # frontend concern; this list intentionally contains roots only.
    def parent_options
      sort_sections(roots).map do |section|
        {
          id: section.id,
          name: section.name,
          section_type: section.section_type,
          depth: 1
        }
      end
    end

    # Page-level permissions for the structure UI when the tree is empty or for
    # actions that are not tied to a single node (§5.6 / §8.4).
    def page_permissions
      manage = can_manage?
      operable = property_operable?(property)

      {
        view: manage,
        manage: manage && operable,
        create_root: manage && operable
      }
    end

    private

    attr_reader :actor, :property

    # Sections loaded from the authorized property only; never an external
    # collection (§5.1). Eager-loads units only when requested to avoid N+1 (§5.10).
    def sections
      @sections ||= begin
        scope = property.property_sections
        scope = scope.where.not(status: SectionStatuses::ARCHIVED) unless @include_archived
        scope = scope.includes(:units) if @include_units
        scope.to_a
      end
    end

    def section_ids
      @section_ids ||= sections.map(&:id).to_set
    end

    def by_parent
      @by_parent ||= sections.group_by(&:parent_id)
    end

    # Root nodes are sections without a parent plus any orphan whose parent is not
    # part of the loaded set (defensive against dangling references, §5.9).
    def roots
      @roots ||= sections.reject { |section| section.parent_id && section_ids.include?(section.parent_id) }
    end

    def build_nodes(sections, depth:, path:, inherited_status:, seen: Set.new)
      sort_sections(sections).filter_map do |section|
        # Cycle guard: never visit a section twice on the same branch (§5.9).
        next if seen.include?(section.id)

        node_path = path + [ section.name ]
        node_effective = most_restrictive(inherited_status, section.status)
        child_sections = depth < MAX_DEPTH ? (by_parent[section.id] || []) : []
        children = build_nodes(
          child_sections,
          depth: depth + 1,
          path: node_path,
          inherited_status: node_effective,
          seen: seen + [ section.id ]
        )

        node(section, depth: depth, path: node_path, effective_status: node_effective, children: children)
      end
    end

    def node(section, depth:, path:, effective_status:, children:)
      is_root = section.parent_id.nil?
      effectively_active = effective_status == SectionStatuses::ACTIVE

      base = {
        id: section.id,
        name: section.name,
        code: section.code,
        normalized_name: section.normalized_name,
        section_type: section.section_type,
        position: section.position,
        status: section.status,
        effective_status: effective_status,
        parent_id: section.parent_id,
        depth: depth,
        path: path,
        selected: false,
        disabled: !effectively_active,
        permissions: permissions(section, is_root: is_root, effectively_active: effectively_active),
        children: children
      }
      base[:units] = build_units(section, children) if @include_units
      base
    end

    # Backend-driven, per-node action availability (§5.6/§5.7). +add_child+ is only
    # ever +true+ for an effectively-active root when the actor may manage sections
    # and the property accepts mutations; for subsections it is always +false+.
    def permissions(section, is_root:, effectively_active:)
      {
        view: can_manage?,
        edit: can_manage?,
        move: can_manage?,
        add_child: is_root && can_manage? && property_operable?(property) && effectively_active,
        archive: can_manage? && section.status != SectionStatuses::ARCHIVED
      }
    end

    def build_units(section, children)
      return [] if children.any?

      section.units.sort_by { |unit| [ unit.identifier.to_s.downcase, unit.id ] }.map do |unit|
        {
          id: unit.id,
          identifier: unit.identifier,
          display_name: unit.display_name,
          unit_type: unit.unit_type,
          area_m2: unit.area_m2
        }
      end
    end

    # Stable sibling ordering: position, then normalized name, then id (§5.3).
    def sort_sections(collection)
      collection.sort_by do |section|
        [ section.position || Float::INFINITY, section.normalized_name.to_s, section.id ]
      end
    end

    def most_restrictive(*statuses)
      statuses.compact.max_by { |status| STATUS_SEVERITY.fetch(status, 0) }
    end

    def can_manage?
      return @can_manage if defined?(@can_manage)

      policy = PropertySectionPolicy.new(actor, PropertySection)
      @can_manage = policy.allowed?(:manage_sections) ||
                    policy.property_allowed?(:manage_sections, property: property)
    end

    include PropertyOperable
  end
end
