# frozen_string_literal: true

module PropertySections
  # Creates N sections under a single context (N roots, or N children of one root)
  # in one transaction, reusing {PropertySections::Create} per node so every
  # +PropertySectionHierarchy+ rule and the two-level limit still apply
  # (wizard-manual-structure-builder).
  #
  # Names come from {Properties::Setup::SectionNameSequence}: either an explicit
  # +names+ list (individual mode) or generated from +prefix+/+suffix_type+/+count+
  # (multiple mode), skipping siblings whose normalized name is already taken.
  # Because each node goes through +Create+, a child batch under a non-root parent
  # is rejected by the hierarchy validation; any single failure rolls back the
  # whole batch and returns the failing node with its errors.
  class CreateBatch < Base
    def initialize(actor:, property:, parent: nil, section_type:, names: nil,
                   prefix: nil, suffix_type: :letter, count: nil)
      super(actor: actor)
      @property = property
      @parent = parent
      @section_type = section_type
      @names = names
      @prefix = prefix
      @suffix_type = suffix_type
      @count = count
    end

    def call
      authorize_manage_sections!(@property)

      names = resolved_names

      # In batch mode, allocating fewer free names than requested (including zero,
      # when every sibling suffix is already taken) is an insufficiency — checked
      # before the generic empty guard so it is not misreported as an empty batch.
      if batch_mode?
        return BatchResult.invalid(insufficient_batch_section) if names.size < @count.to_i
      elsif names.empty?
        return BatchResult.invalid(blank_batch_section)
      end

      created = []
      ActiveRecord::Base.transaction do
        names.each_with_index do |name, index|
          result = PropertySections::Create.call(
            actor: actor,
            property: @property,
            parent: @parent,
            attributes: { name: name, section_type: @section_type }
          )

          unless result.success?
            @failed_section = result.section
            raise ActiveRecord::Rollback
          end

          created << result.section
        end
      end

      return BatchResult.invalid(@failed_section) if @failed_section

      BatchResult.success(created)
    end

    private

    def batch_mode?
      @names.blank? && @prefix.present? && @count.to_i.positive?
    end

    def resolved_names
      return Array(@names).map(&:to_s).reject(&:blank?) if @names.present?
      return [] if @prefix.blank? || @count.to_i <= 0

      Properties::Setup::SectionNameSequence.available_names(
        prefix: @prefix,
        suffix_type: @suffix_type,
        count: @count,
        taken_normalized_names: sibling_normalized_names
      )
    end

    def sibling_normalized_names
      @property.property_sections.where(parent_id: @parent&.id).pluck(:normalized_name)
    end

    def blank_batch_section
      section = PropertySection.new(section_type: @section_type)
      assign_organization_from_property!(section, @property)
      section.errors.add(:base, :empty_batch)
      section
    end

    def insufficient_batch_section
      section = PropertySection.new(section_type: @section_type)
      assign_organization_from_property!(section, @property)
      section.errors.add(:base, :insufficient_available_names, count: @count.to_i)
      section
    end
  end
end
