# frozen_string_literal: true

class Admin::ResidentialPropertiesController < AdminController
  include RespondsToPropertyResult

  before_action :get_residential_property, only: %i[show archive]

  def index
    authorize ResidentialProperty
    @q = policy_scope(ResidentialProperty).ransack(params[:q])
    residential_properties = @q.result(distinct: true)
      .order(created_at: :desc)
      .page(@filters[:page])
      .per(@filters[:per_page])

    pagination = pagination_info(residential_properties)
    render inertia: "admin/residential_properties/index", props: {
      residential_properties: serialize_properties(residential_properties),
      pagination: pagination
    }, status: :ok
  end

  def new
    authorize ResidentialProperty
    redirect_to admin_property_setup_new_wizard_path
  end

  def create
    authorize ResidentialProperty
    redirect_to admin_property_setup_new_wizard_path
  end

  def show
    authorize @residential_property

    render inertia: "admin/residential_properties/show", props: {
      residential_property: Admin::ResidentialPropertyDetailSerializer.new(
        property: @residential_property, current_user: current_user
      ).as_json
    }, status: :ok
  end

  def archive
    authorize @residential_property, :archive?

    result = Properties::Archive.call(
      actor: current_user,
      property: @residential_property
    )
    respond_to_property_result(
      result,
      success_path: admin_residential_properties_path,
      error_path: admin_residential_properties_path
    )
  end

  private

  def get_residential_property
    @residential_property = policy_scope(ResidentialProperty).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_residential_properties_path,
                inertia: { errors: { base: [ I18n.t("frontend.admin.residential_properties.not_found") ] } }
  end

  def serialize_property(property)
    Admin::ResidentialPropertySerializer.new(property, current_user: current_user).as_json
  end

  def serialize_properties(properties)
    properties.map { |property| serialize_property(property) }
  end
end
