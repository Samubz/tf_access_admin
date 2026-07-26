# frozen_string_literal: true

class Admin::ResidentialProperties::UnitOccupanciesController < AdminController
  OCCUPANCY_ASSIGNMENT_PARAMS = %i[occupancy_type can_authorize_visits starts_at ends_at status].freeze
  OCCUPANCY_CREATE_PARAMS = (%i[person_id] + OCCUPANCY_ASSIGNMENT_PARAMS).freeze
  MINIMAL_PERSON_PARAMS = %i[first_name last_name display_name email document_number person_type].freeze

  before_action :set_residential_property
  before_action :set_unit
  before_action :set_occupancy, only: %i[update destroy]

  def create
    authorize UnitOccupancy

    create_occupancy!
    redirect_to_unit_show
  rescue ActiveRecord::RecordInvalid => e
    redirect_to_unit_show_with_errors(e.record)
  end

  def update
    authorize @occupancy

    update_occupancy!
    redirect_to_unit_show
  rescue ActiveRecord::RecordInvalid => e
    redirect_to_unit_show_with_errors(e.record)
  end

  def destroy
    authorize @occupancy

    destroy_occupancy!
    redirect_to_unit_show
  rescue ActiveRecord::RecordInvalid => e
    redirect_to_unit_show_with_errors(e.record)
  end

  def active_elsewhere
    authorize UnitOccupancy, :create?

    person = @unit.organization.people.find(params.require(:person_id))
    occupancies = UnitOccupancies::ActiveElsewhereForPerson.call(
      person: person,
      exclude_unit: @unit
    )

    render json: { active_elsewhere_occupancies: occupancies }
  rescue ActiveRecord::RecordNotFound
    render json: { active_elsewhere_occupancies: [] }, status: :not_found
  end

  private

  def create_occupancy!
    if occupancy_params[:person_id].present?
      UnitOccupancies::Create.call(
        unit: @unit,
        occupancy_params: occupancy_params,
        actor: current_user
      )
    else
      UnitOccupancies::CreateWithPerson.call(
        unit: @unit,
        occupancy_params: occupancy_params,
        person_params: person_params,
        actor: current_user
      )
    end
  end

  def update_occupancy!
    UnitOccupancies::Update.call(
      occupancy: @occupancy,
      occupancy_params: occupancy_params,
      actor: current_user
    )
  end

  def destroy_occupancy!
    UnitOccupancies::Destroy.call(
      occupancy: @occupancy,
      actor: current_user
    )
  end

  def occupancy_params
    keys = action_name == "create" ? OCCUPANCY_CREATE_PARAMS : OCCUPANCY_ASSIGNMENT_PARAMS
    params.require(:unit_occupancy).permit(*keys)
  end

  def person_params
    return {} unless params[:person].present?

    params.require(:person).permit(*MINIMAL_PERSON_PARAMS).tap do |permitted|
      permitted[:contact_email] = permitted.delete(:email) if permitted.key?(:email)
    end
  end

  def redirect_to_unit_show(**options)
    redirect_to unit_show_path, **options
  end

  def redirect_to_unit_show_with_errors(record)
    redirect_to_unit_show inertia: { errors: serialize_inertia_errors(record) }
  end

  def unit_show_path
    admin_residential_property_unit_path(@residential_property, @unit, tab: "occupants")
  end

  def set_residential_property
    @residential_property = policy_scope(ResidentialProperty).find(params[:residential_property_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_residential_properties_path,
                inertia: { errors: [ I18n.t("frontend.admin.residential_properties.not_found") ] }
  end

  def set_unit
    @unit = policy_scope(Unit)
      .where(residential_property: @residential_property)
      .find(params[:unit_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_residential_properties_path,
                inertia: { errors: [ I18n.t("frontend.admin.units.not_found") ] }
  end

  def set_occupancy
    @occupancy = policy_scope(UnitOccupancy)
      .where(unit: @unit)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to unit_show_path,
                inertia: { errors: [ I18n.t("frontend.admin.unit_occupancies.not_found") ] }
  end
end
