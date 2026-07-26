# frozen_string_literal: true

# Single source of truth for the property-section hierarchy
# (improve-property-sections §3). The tree is limited to two levels within a
# property: root sections (no parent) and subsections (parent is a root). This
# concern owns parent coherence, acyclicity, the two-level limit, and the
# effective-status computation derived from the property and ancestor chain.
module PropertySectionHierarchy
  extend ActiveSupport::Concern

  # Status precedence for effective-status: the most restrictive wins.
  STATUS_SEVERITY = {
    SectionStatuses::ACTIVE => 0,
    SectionStatuses::INACTIVE => 1,
    SectionStatuses::ARCHIVED => 2
  }.freeze

  included do
    validate :cannot_be_own_parent
    validate :parent_must_exist
    validate :parent_in_same_organization_and_property
    validate :parent_must_be_root_section
    validate :section_with_children_cannot_be_nested
    validate :parent_not_descendant
    validate :parent_must_be_operative
    validate :parent_cannot_have_units
    validate :container_cannot_have_units
  end

  def root_section?
    parent_id.blank?
  end

  def child_section?
    parent_id.present?
  end

  def accepts_child_sections?
    root_section?
  end

  def accepts_units?
    children.none?
  end

  # §3.8: effective status derived from the property, the ancestor chain and the
  # section itself. The most restrictive status (archived > inactive > active)
  # wins, so a section stays +active+ in intent but becomes non-operational under
  # an inactive/archived ancestor or property.
  def effective_status
    chain = [ status, residential_property&.status, *ancestor_chain.map(&:status) ].compact
    chain.max_by { |value| STATUS_SEVERITY.fetch(value, 0) } || status
  end

  def effectively_active?
    effective_status == SectionStatuses::ACTIVE
  end

  # Ancestor sections from the parent up to the root, guarding against cycles.
  # Excludes self.
  def ancestor_chain
    chain = []
    seen = [ id ].compact
    current = parent
    while current && seen.exclude?(current.id)
      chain << current
      seen << current.id
      current = current.parent
    end
    chain
  end

  def descendant_ids
    ids = []
    seen = []
    queue = children.to_a
    while queue.any?
      child = queue.shift
      next if seen.include?(child.id)

      seen << child.id
      ids << child.id
      queue.concat(child.children.to_a)
    end
    ids
  end

  private

  # §3.4
  def cannot_be_own_parent
    return if parent_id.blank? || id.blank?
    return unless parent_id == id

    errors.add(:parent_id, t_validation("parent_invalid"))
  end

  def parent_must_exist
    return if parent_id.blank?
    return if parent.present?

    errors.add(:parent_id, t_validation("parent_invalid"))
  end

  # §3.3
  def parent_in_same_organization_and_property
    return if parent_id.blank? || parent.nil?

    unless parent.organization_id == organization_id
      errors.add(:parent_id, t_validation("parent_same_organization"))
      return
    end

    return if parent.residential_property_id == residential_property_id

    errors.add(:parent_id, t_validation("parent_same_property"))
  end

  # §3.2/§3.5: the parent must be a root section, so sections can never be
  # created or moved under a subsection (which would create a third level).
  def parent_must_be_root_section
    return if parent_id.blank? || parent.nil?
    return if parent.root_section?

    errors.add(:parent_id, t_validation("parent_must_be_root"))
  end

  # §3.2/§3.7: a section that already has children cannot become a subsection,
  # which would push its subtree to a third level.
  def section_with_children_cannot_be_nested
    return if parent_id.blank?
    return unless children.exists?

    errors.add(:parent_id, t_validation("cannot_nest_with_children"))
  end

  # §3.6: a section cannot use one of its own descendants as parent.
  def parent_not_descendant
    return if parent_id.blank? || id.blank?
    return unless descendant_ids.include?(parent_id)

    errors.add(:parent_id, t_validation("parent_circular"))
  end

  # §3.9: new children / incoming moves are rejected under a parent that is not
  # effectively active (its property or an ancestor is inactive/archived).
  def parent_must_be_operative
    return if parent_id.blank? || parent.nil?
    return unless new_record? || parent_id_changed?
    return if parent.effectively_active?

    errors.add(:parent_id, t_validation("parent_not_operative"))
  end

  def parent_cannot_have_units
    return if parent_id.blank?
    return unless parent&.units&.exists?

    errors.add(:parent_id, t_validation("parent_has_units"))
  end

  def container_cannot_have_units
    return unless units.exists?
    return if children.none?

    errors.add(:base, t_validation("container_cannot_have_units"))
  end

  def t_validation(key)
    I18n.t("frontend.admin.property_sections.validations.#{key}")
  end
end
