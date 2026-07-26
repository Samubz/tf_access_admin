# frozen_string_literal: true

# Lightweight unit payload for catalog/search surfaces (improve-units-foundation §6.6).
class Admin::UnitSummarySerializer < ActiveModel::Serializer
  attributes :id,
    :identifier,
    :code,
    :display_name,
    :unit_type,
    :status,
    :residential_property_id,
    :property_section_id,
    :property_section_name,
    :residential_property_name,
    :permissions,
    :actions

  def residential_property_name
    object.residential_property&.name
  end

  def property_section_name
    object.property_section&.name
  end

  def permissions
    @permissions ||= begin
      policy = unit_policy
      {
        view: policy.show?,
        update: policy.update?,
        move: policy.move?,
        archive: policy.archive?,
        restore: policy.restore?
      }
    end
  end

  def actions
    permissions.filter_map { |action, allowed| action.to_s if allowed }
  end

  private

  def unit_policy
    @instance_options[:policy] || UnitPolicy.new(current_user, object)
  end

  def current_user
    @instance_options[:current_user] || scope
  end
end
