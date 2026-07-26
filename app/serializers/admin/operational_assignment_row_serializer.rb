# frozen_string_literal: true

class Admin::OperationalAssignmentRowSerializer < ActiveModel::Serializer
  attributes :id, :person_id, :person_name, :user_email, :user_name, :role, :role_key, :staff_type,
             :residential_property_id, :property_name, :scope_label, :status, :starts_at, :ends_at

  def person_name
    object.person&.display_name
  end

  def user_email
    object.person&.user&.email
  end

  def user_name
    object.person&.user&.name
  end

  def role
    role_key = Authorization::StaffRoleMapper.operational_role_for(object.staff_type)
    OperationalRoles::Presentation.role_name(role_key) if role_key
  end

  def role_key
    Authorization::StaffRoleMapper.operational_role_for(object.staff_type)
  end

  def property_name
    object.residential_property&.name
  end

  def scope_label
    OperationalRoles::Presentation.scope_label("property", property_name: object.residential_property&.name)
  end
end
