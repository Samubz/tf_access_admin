# frozen_string_literal: true

class Admin::OperationalRolesController < AdminController
  def index
    authorize nil, :index?, policy_class: OperationalRolePolicy

    assignments_scope = scoped_assignments.includes(:person, :residential_property)

    roles_with_counts = OperationalRoles::RoleDefinitions.all_for_matrix.map do |role|
      OperationalRoles::Presentation.role_json(role, users_count: users_count_for(role, assignments_scope))
    end

    render inertia: "admin/operational_roles/index", props: {
      roles: roles_with_counts,
      summary: {
        defined_roles_count: OperationalRoles::RoleDefinitions.all_for_matrix.size,
        total_capabilities_count: Authorization::Capabilities::ALL.size,
        total_assignments_count: assignments_scope.count,
        assigned_users_count: assignments_scope.select(:person_id).distinct.count
      },
      capability_matrix: OperationalRoles::Presentation.capability_matrix(OperationalRoles::RoleDefinitions.all_for_matrix),
      matrix_role_columns: OperationalRoles::Presentation.matrix_role_columns,
      permissions: {
        manage: operational_role_policy.create?
      }
    }
  end

  def show
    authorize nil, :show?, policy_class: OperationalRolePolicy

    role = OperationalRoles::RoleDefinitions.find(params[:role])
    return redirect_to admin_operational_roles_path unless role

    render inertia: "admin/operational_roles/show", props: {
      role: OperationalRoles::Presentation.role_json(role, users_count: users_count_for(role, scoped_assignments)).merge(
        capabilities: role[:capabilities].map(&:to_s)
      ),
      users: users_for_role(role),
      capability_groups: OperationalRoles::Presentation.capability_groups_for_role(role),
      permissions: {
        manage: operational_role_policy.create?
      }
    }
  end

  private

  def operational_role_policy
    OperationalRolePolicy.new(current_user, nil)
  end

  def scoped_assignments
    base = Authorization::Resolver.new(user: current_user, organization: Current.organization)
    if base.profile.organization_wide?
      StaffAssignment.currently_active
    else
      StaffAssignment.currently_active.where(residential_property_id: base.accessible_property_ids)
    end
  end

  def users_count_for(role, assignments_scope)
    if role[:staff_types].present?
      assignments_scope.where(staff_type: role[:staff_types]).select(:person_id).distinct.count
    elsif role[:org_role].present?
      Person.where(organization_id: Current.organization.id)
            .joins(:roles)
            .where(roles: { name: role[:org_role], organization_id: Current.organization.id })
            .distinct
            .count
    else
      0
    end
  end

  def users_for_role(role)
    if role[:staff_types].present?
      scoped_assignments
        .where(staff_type: role[:staff_types])
        .includes(:person, :residential_property)
        .map { |a| assignment_user_row(a) }
    elsif role[:org_role].present?
      Person.where(organization_id: Current.organization.id)
            .joins(:roles)
            .where(roles: { name: role[:org_role], organization_id: Current.organization.id })
            .includes(:user)
            .distinct
            .map { |person| org_role_user_row(person) }
    else
      []
    end
  end

  def assignment_user_row(assignment)
    {
      assignment_id: assignment.id,
      person_id: assignment.person_id,
      person_name: assignment.person&.display_name,
      user_email: assignment.person&.user&.email,
      property_id: assignment.residential_property_id,
      property_name: assignment.residential_property&.name,
      scope_label: OperationalRoles::Presentation.scope_label("property", property_name: assignment.residential_property&.name),
      status: assignment.status,
      starts_at: assignment.starts_at,
      ends_at: assignment.ends_at
    }
  end

  def org_role_user_row(person)
    {
      assignment_id: nil,
      person_id: person.id,
      person_name: person.display_name,
      user_email: person.user&.email,
      property_id: nil,
      property_name: nil,
      scope_label: OperationalRoles::Presentation.scope_label("organization"),
      status: StaffAssignment::STATUS_ACTIVE,
      starts_at: nil,
      ends_at: nil
    }
  end
end
