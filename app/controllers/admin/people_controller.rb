# frozen_string_literal: true

class Admin::PeopleController < AdminController
  before_action :set_person, only: [ :create ]
  before_action :get_person, only: [ :show, :edit, :update, :destroy, :invite ]
  before_action :set_profile_filters, only: [ :show ]
  before_action :validate_role, only: [ :create, :update ]

  def index
    authorize Person
    @q = policy_scope(Person).ransack(params[:q])
    people = @q.result(distinct: true)
      .includes(:user, :onboarding_requests)
      .order(created_at: :desc)
      .page(@filters[:page])
      .per(@filters[:per_page])

    people_records = people.to_a
    contextual_roles_by_person = People::ContextualRoles.batch_for(people_records)
    pagination = pagination_info(people)
    payload = {
      people: people_records.map do |person|
        Admin::PersonSerializer.new(person).as_json.merge(
          contextual_roles: contextual_roles_by_person.fetch(person.id, [])
        )
      end,
      pagination: pagination
    }

    if request.format.json?
      render json: payload
    else
      render inertia: "admin/people/index", props: payload, status: :ok
    end
  end

  def show
    authorize @person, :show?

    ownerships = ownerships_scope
      .page(@profile_filters[:ownerships_page])
      .per(@profile_filters[:ownerships_per_page])

    occupancies = occupancies_scope
      .page(@profile_filters[:occupancies_page])
      .per(@profile_filters[:occupancies_per_page])

    render inertia: "admin/people/show", props: profile_props(
      ownerships: ownerships,
      occupancies: occupancies
    ), status: :ok
  end

  def new
    authorize Person
    render inertia: "admin/people/new", props: form_props
  end

  def create
    authorize Person

    if @validation_errors || !save_person_with_membership(@person)
      redirect_to new_admin_person_path, inertia: { errors: @person.errors }
    else
      send_invitation_if_requested(@person)
      redirect_to admin_people_path
    end
  end

  def invite
    authorize @person, :invite?

    result = Accounts::InvitePerson.call_for_person(
      person: @person,
      requested_by_person: current_user.person_for(ActsAsTenant.current_tenant)
    )
    Accounts::InvitePerson.deliver(result)
    redirect_to admin_people_path
  rescue Accounts::InvitePerson::AlreadyInvited
    redirect_to admin_people_path,
                inertia: { errors: { base: [ "admin.people.errors.already_invited" ] } }
  rescue Accounts::InvitePerson::MissingEmail
    redirect_to admin_people_path,
                inertia: { errors: { base: [ "admin.people.errors.missing_email" ] } }
  end

  def edit
    authorize @person

    person_json = Admin::PersonSerializer.new(@person).as_json
    person_json[:role] = person_json[:tenant_role]
    render inertia: "admin/people/edit", props: form_props(person: person_json)
  end

  def update
    authorize @person

    if @validation_errors || !update_person_with_membership(@person)
      redirect_to edit_admin_person_path(@person), inertia: { errors: @person.errors }
    else
      redirect_to edit_admin_person_path(@person)
    end
  end

  def destroy
    authorize @person
    @person.destroy
    redirect_to admin_people_path
  end

  private

  def profile_props(ownerships:, occupancies:)
    {
      person: Admin::PersonSerializer.new(@person).as_json,
      contextual_roles: People::ContextualRoles.call(@person),
      summary: Person::ProfileSummary.for(@person),
      ownerships: ownerships.map { |ownership| Admin::PersonOwnershipRowSerializer.new(ownership).as_json },
      ownerships_pagination: pagination_info(
        ownerships,
        per_page: @profile_filters[:ownerships_per_page]
      ),
      occupancies: occupancies.map { |occupancy| Admin::PersonOccupancyRowSerializer.new(occupancy).as_json },
      occupancies_pagination: pagination_info(
        occupancies,
        per_page: @profile_filters[:occupancies_per_page]
      ),
      change_history: Person::ChangeHistory.for(@person),
      staff_assignments: staff_assignments_props,
      visits: [],
      permissions: profile_permissions
    }
  end

  def staff_assignments_props
    @person.staff_assignments
      .currently_active
      .includes(:residential_property)
      .map { |assignment| Admin::PersonStaffAssignmentSerializer.new(assignment).as_json }
  end

  def profile_permissions
    {
      view: policy(@person).show?,
      update: policy(@person).update?,
      destroy: policy(@person).destroy?,
      edit: policy(@person).edit?
    }
  end

  def ownerships_scope
    @person.unit_ownerships
      .includes(unit: [ :residential_property, :property_section ])
      .ordered_for_display
  end

  def occupancies_scope
    @person.unit_occupancies
      .includes(unit: [ :residential_property, :property_section ])
      .ordered_for_display
  end

  def set_profile_filters
    @profile_filters = {
      ownerships_page: params[:ownerships_page] || 1,
      ownerships_per_page: params[:ownerships_per_page] || 10,
      occupancies_page: params[:occupancies_page] || 1,
      occupancies_per_page: params[:occupancies_per_page] || 10
    }
  end

  def form_props(person: nil)
    {
      person: person,
      roles: AvailableRoles::TENANT,
      person_types: PersonTypes::ALL,
      statuses: PersonStatuses::ALL
    }
  end

  def set_person
    @person = Person.new(person_params)
    @person.organization ||= ActsAsTenant.current_tenant
    @validation_errors = false
  end

  def get_person
    @person = policy_scope(Person).includes(:user).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_people_path, inertia: { errors: { base: [ I18n.t("frontend.admin.people.not_found") ] } }
  end

  def save_person_with_membership(person)
    Person.transaction do
      person.save!
      ensure_membership!(person)
      apply_role!(person)
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def update_person_with_membership(person)
    Person.transaction do
      person.update!(person_params)
      ensure_membership!(person)
      apply_role!(person)
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def send_invitation_if_requested(person)
    return unless ActiveModel::Type::Boolean.new.cast(params.dig(:person, :send_invitation))
    return if person.contact_email.blank?

    result = Accounts::InvitePerson.call_for_person(
      person: person,
      requested_by_person: current_user.person_for(ActsAsTenant.current_tenant)
    )
    Accounts::InvitePerson.deliver(result)
  rescue Accounts::InvitePerson::AlreadyInvited
    nil
  end

  def ensure_membership!(person)
    membership = person.organization_membership
    return membership if membership.present?

    membership = OrganizationMembership.create!(organization: person.organization, person: person)
    membership.accept! if membership.may_accept?
    membership
  end

  def apply_role!(person)
    role = params.dig(:person, :role)
    return if role.blank?

    person.set_tenant_role(role)
  end

  def validate_role
    role = params.dig(:person, :role)
    return if role.blank?

    unless AvailableRoles::TENANT.include?(role)
      target = @person || Person.new
      target.errors.add(:role, "admin.people.validations.role_invalid")
      @validation_errors = true
    end
  end

  def person_params
    params.require(:person).permit(
      :first_name,
      :last_name,
      :document_number,
      :email,
      :phone,
      :birthdate
    ).tap do |permitted|
      permitted[:contact_email] = permitted.delete(:email) if permitted.key?(:email)
      permitted[:contact_phone] = permitted.delete(:phone) if permitted.key?(:phone)
    end
  end
end
