# frozen_string_literal: true

class Admin::OperationalRoles::AssignmentsController < AdminController
  before_action :set_assignment, only: [ :destroy ]

  def index
    authorize nil, :index?, policy_class: OperationalRolePolicy

    assignments = scoped_assignments.includes(:residential_property, person: :user)
    assignments = filter_assignments(assignments)
    assignments = assignments.order(created_at: :desc).page(@filters[:page]).per(@filters[:per_page])

    render inertia: "admin/operational_roles/assignments/index", props: {
      assignments: assignments.map { |a| Admin::OperationalAssignmentRowSerializer.new(a).as_json },
      pagination: pagination_info(assignments),
      available_roles: OperationalRoles::RoleDefinitions.assignable.map { |r|
        OperationalRoles::Presentation.role_json(r, users_count: 0).slice(:key, :name, :scope, :scope_label)
      },
      accessible_properties: accessible_properties.map { |p| { id: p.id, name: p.name } },
      assignable_people: assignable_people,
      permissions: {
        create: operational_role_policy.create?,
        destroy: operational_role_policy.create?
      }
    }
  end

  def create
    authorize nil, :create?, policy_class: OperationalRolePolicy

    result = build_and_call_service
    if result.nil?
      redirect_to admin_operational_roles_assignments_path,
        inertia: { errors: { base: [ I18n.t("operational_roles.errors.unknown_role") ] } }
    elsif result[:success]
      redirect_to admin_operational_roles_assignments_path
    else
      redirect_to admin_operational_roles_assignments_path,
        inertia: { errors: { base: result[:errors] } }
    end
  end

  def destroy
    authorize @assignment, :destroy?, policy_class: OperationalRolePolicy

    result = OperationalRoles::RevokeAssignment.new(actor: current_user, assignment: @assignment).call
    if result[:success]
      redirect_to admin_operational_roles_assignments_path
    else
      redirect_to admin_operational_roles_assignments_path,
        inertia: { errors: { base: result[:errors] } }
    end
  end

  private

  def set_assignment
    @assignment = StaffAssignment.find_by(id: params[:id], organization_id: Current.organization.id)
    redirect_to admin_operational_roles_assignments_path unless @assignment
  end

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

  def filter_assignments(scope)
    if params[:q].present?
      query = "%#{params[:q].downcase}%"
      scope = scope.joins(:person).left_joins(person: :user).where(
        "LOWER(persons.display_name) LIKE :q OR LOWER(users.email) LIKE :q",
        q: query
      )
    end
    if params[:role].present?
      role_def = OperationalRoles::RoleDefinitions.find(params[:role])
      scope = scope.where(staff_type: role_def[:staff_types]) if role_def&.dig(:staff_types)&.present?
    end
    scope = scope.where(residential_property_id: params[:property_id]) if params[:property_id].present?
    scope
  end

  def accessible_properties
    base = Authorization::Resolver.new(user: current_user, organization: Current.organization)
    if base.profile.organization_wide?
      ResidentialProperty.order(:name)
    else
      ResidentialProperty.where(id: base.accessible_property_ids).order(:name)
    end
  end

  def assignable_people
    Person.where(organization_id: Current.organization.id)
          .includes(:user)
          .order(:display_name)
          .map do |person|
            {
              id: person.id,
              display_name: person.display_name,
              user_email: person.user&.email,
              has_user: person.user_id.present?
            }
          end
  end

  def build_and_call_service
    person = Person.find_by(id: params[:person_id], organization_id: Current.organization.id)
    property = ResidentialProperty.find_by(id: params[:residential_property_id], organization_id: Current.organization.id)
    return nil unless person && property

    base_args = {
      actor: current_user,
      person: person,
      organization: Current.organization,
      residential_property: property,
      starts_at: parse_date(params[:starts_at]),
      ends_at: parse_date(params[:ends_at]),
      status: params[:status].presence || StaffAssignment::STATUS_ACTIVE
    }

    case params[:role]
    when "property_admin"
      OperationalRoles::AssignPropertyAdmin.new(**base_args).call
    when "concierge"
      OperationalRoles::AssignConcierge.new(**base_args).call
    when "cleaning_staff"
      OperationalRoles::AssignInternalStaff.new(**base_args, staff_type: StaffTypes::CLEANING).call
    when "internal_staff"
      OperationalRoles::AssignInternalStaff.new(**base_args, staff_type: StaffTypes::MAINTENANCE).call
    end
  end

  def parse_date(value)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end
