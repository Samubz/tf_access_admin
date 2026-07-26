# frozen_string_literal: true

# Administrative serializer for Unit detail surfaces (improve-units-foundation §6.6).
class Admin::UnitSerializer < ActiveModel::Serializer
  attributes :id,
    :identifier,
    :code,
    :display_name,
    :title,
    :unit_type,
    :status,
    :area_m2,
    :residential_property_id,
    :residential_property_name,
    :property_section_id,
    :location_path,
    :ownership_stats,
    :occupancy_stats,
    :permissions,
    :actions

  def title
    return object.display_name if object.display_name.present?

    I18n.t("frontend.admin.units.show.unit_title", identifier: object.identifier)
  end

  def residential_property_name
    instance_options[:residential_property_name] || object.residential_property&.name
  end

  def location_path
    instance_options[:location_path] || []
  end

  def ownership_stats
    instance_options[:ownership_stats] || Unit::OwnershipStats.for(object)
  end

  def occupancy_stats
    instance_options[:occupancy_stats] || Unit::OccupancyStats.for(object)
  end

  def permissions
    @permissions ||= begin
      policy = unit_policy
      {
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
