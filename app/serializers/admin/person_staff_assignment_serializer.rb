# frozen_string_literal: true

class Admin::PersonStaffAssignmentSerializer < ActiveModel::Serializer
  attributes :id,
    :residential_property_name,
    :role,
    :status,
    :starts_at,
    :ends_at

  def residential_property_name
    object.residential_property&.name
  end

  def role
    Authorization::StaffRoleMapper.operational_role_for(object.staff_type)
  end
end
