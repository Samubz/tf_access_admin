# frozen_string_literal: true

class Admin::ResidentialProperties::UnitOwnershipsController < AdminController
  OWNERSHIP_ASSIGNMENT_PARAMS = %i[ownership_percentage starts_at ends_at status].freeze
  OWNERSHIP_CREATE_PARAMS = (%i[person_id] + OWNERSHIP_ASSIGNMENT_PARAMS).freeze
  MINIMAL_PERSON_PARAMS = %i[first_name last_name display_name email document_number person_type].freeze

  before_action :set_residential_property
  before_action :set_unit
  before_action :set_ownership, only: %i[update destroy]

  def create
    authorize UnitOwnership

    create_ownership!
    redirect_to_unit_show
  rescue ActiveRecord::RecordInvalid => e
    redirect_to_unit_show_with_errors(e.record)
  end

  def update
    authorize @ownership

    UnitOwnerships::Update.call(
      ownership: @ownership,
      ownership_params: ownership_params,
      actor: current_user
    )

    redirect_to_unit_show
  rescue ActiveRecord::RecordInvalid => e
    redirect_to_unit_show_with_errors(e.record)
  end

  def destroy
    authorize @ownership

    UnitOwnerships::Destroy.call(
      ownership: @ownership,
      actor: current_user
    )

    redirect_to_unit_show
  rescue ActiveRecord::RecordInvalid => e
    redirect_to_unit_show_with_errors(e.record)
  end

  private

  def create_ownership!
    if ownership_params[:person_id].present?
      UnitOwnerships::Create.call(
        unit: @unit,
        ownership_params: ownership_params,
        actor: current_user
      )
    else
      UnitOwnerships::CreateWithPerson.call(
        unit: @unit,
        ownership_params: ownership_params,
        person_params: person_params,
        actor: current_user
      )
    end
  end

  def ownership_params
    keys = action_name == "create" ? OWNERSHIP_CREATE_PARAMS : OWNERSHIP_ASSIGNMENT_PARAMS
    params.require(:unit_ownership).permit(*keys)
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
    admin_residential_property_unit_path(@residential_property, @unit, tab: "owners")
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

  def set_ownership
    @ownership = policy_scope(UnitOwnership)
      .where(unit: @unit)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to unit_show_path,
                inertia: { errors: [ I18n.t("frontend.admin.unit_ownerships.not_found") ] }
  end
end
