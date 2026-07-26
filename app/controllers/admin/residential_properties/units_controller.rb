# frozen_string_literal: true

# Canonical channel for unit mutations (improve-units-foundation §6.1).
# Every action loads tenant-safe records through policy scopes (§6.3), authorizes
# with property context, and delegates to a domain service (§6.2). Organization
# and property come from the nested route, never from client params (§6.4).
class Admin::ResidentialProperties::UnitsController < AdminController
  include RespondsToUnitResult

  before_action :set_residential_property
  before_action :set_unit, only: %i[show update]
  before_action :set_restorable_unit, only: [ :restore ]
  before_action :set_filters, only: %i[index show]

  def index
    authorize Unit

    units = searchable_units
      .order(:identifier)
      .page(@filters[:page])
      .per(@filters[:per_page])

    render json: {
      units: units.map { |unit| serialize_unit_summary(unit) },
      pagination: pagination_info(units)
    }
  end

  def show
    authorize @unit

    sections = policy_scope(PropertySection)
      .where(residential_property: @residential_property)
      .to_a
    sections_by_id = sections.index_by(&:id)

    location_path = if @unit.property_section_id.present?
      section = sections_by_id[@unit.property_section_id]
      PropertySection::BreadcrumbPath.build(section, sections_by_id: sections_by_id)
    else
      []
    end

    ownerships = @unit.unit_ownerships
      .includes(:person)
      .ordered_for_display
      .page(@filters[:page])
      .per(@filters[:per_page])

    ownership_stats = Unit::OwnershipStats.for(@unit)

    occupancies_scope = @unit.unit_occupancies
      .includes(:person)
      .ordered_for_display
    occupancies_scope = occupancies_scope.where(status: OccupancyStatuses::ACTIVE) unless occupancies_filters[:include_inactive]
    occupancies = occupancies_scope
      .page(occupancies_filters[:page])
      .per(occupancies_filters[:per_page])

    occupancy_stats = Unit::OccupancyStats.for(@unit)

    visits = policy_scope(Visit)
      .where(unit: @unit)
      .includes(:visitor_person, :unit, :residential_property)
      .order(scheduled_at: :desc)
      .page(visits_filters[:page])
      .per(visits_filters[:per_page])

    render inertia: "admin/units/show", props: {
      unit: Admin::UnitSerializer.new(
        @unit,
        residential_property_name: @residential_property.name,
        location_path: location_path,
        ownership_stats: ownership_stats,
        occupancy_stats: occupancy_stats,
        current_user: current_user
      ).as_json,
      ownerships: ownerships.map { |ownership| Admin::UnitOwnershipSerializer.new(ownership).as_json },
      ownerships_pagination: pagination_info(ownerships),
      occupancies: occupancies.map { |occupancy| Admin::UnitOccupancySerializer.new(occupancy).as_json },
      occupancies_pagination: pagination_info(occupancies, per_page: occupancies_filters[:per_page]),
      occupancy_types: occupancy_type_options,
      occupancy_permissions: occupancy_permissions,
      occupancies_include_inactive: occupancies_filters[:include_inactive],
      visits: visits.map { |visit| Admin::VisitSerializer.new(visit, current_user: current_user).as_json },
      visits_pagination: pagination_info(visits, per_page: visits_filters[:per_page]),
      visit_permissions: visit_permissions,
      change_history: Unit::ChangeHistory.for(@unit)
    }, status: :ok
  end

  def update
    authorize @unit, :update?

    result = Units::Update.call(
      actor: current_user,
      unit: @unit,
      attributes: unit_params
    )
    respond_to_unit_result(
      result,
      success_path: admin_residential_property_unit_path(@residential_property, @unit),
      error_path: admin_residential_property_unit_path(@residential_property, @unit)
    )
  end

  def restore
    authorize @unit, :restore?

    result = Units::Restore.call(actor: current_user, unit: @unit)
    respond_to_unit_result(
      result,
      success_path: admin_residential_properties_path,
      error_path: admin_residential_properties_path
    )
  end

  private

  def searchable_units
    Units::Search.apply(
      policy_scope(Unit).where(residential_property: @residential_property).includes(:property_section),
      term: search_term,
      property_section_id: params.dig(:q, :property_section_id),
      status: params.dig(:q, :status)
    )
  end

  def search_term
    params.dig(:q, :search).presence || params[:search].presence
  end

  def unit_params
    params.require(:unit).permit(
      :identifier, :display_name, :unit_type, :status, :area_m2, :property_section_id,
      metadata: {}
    )
  end

  def serialize_unit_summary(unit)
    Admin::UnitSummarySerializer.new(unit, current_user: current_user).as_json
  end

  def occupancies_filters
    @occupancies_filters ||= {
      page: params[:occupancies_page] || params[:page] || 1,
      per_page: params[:occupancies_per_page] || params[:per_page] || 10,
      include_inactive: ActiveModel::Type::Boolean.new.cast(params[:occupancies_include_inactive]) == true
    }
  end

  def visits_filters
    @visits_filters ||= {
      page: params[:visits_page] || 1,
      per_page: params[:visits_per_page] || 10
    }
  end

  def visit_permissions
    {
      create: can_create_visit_for_unit?
    }
  end

  def can_create_visit_for_unit?
    return false unless @unit

    draft = Visit.new(unit: @unit, organization: @unit.organization)
    VisitPolicy.new(current_user, draft).create?
  end

  def occupancy_type_options
    OccupancyTypes::ALL.map do |type|
      {
        value: type,
        label: I18n.t("frontend.admin.unit_occupancies.occupancy_types.#{type}")
      }
    end
  end

  def occupancy_permissions
    {
      create: policy(UnitOccupancy).create?,
      update: policy(UnitOccupancy).update?,
      destroy: policy(UnitOccupancy).destroy?
    }
  end

  def set_residential_property
    @residential_property = policy_scope(ResidentialProperty).find(params[:residential_property_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_residential_properties_path,
                inertia: { errors: { base: [ I18n.t("frontend.admin.residential_properties.not_found") ] } }
  end

  def set_unit
    @unit = policy_scope(Unit)
      .where(residential_property: @residential_property)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_residential_properties_path,
                inertia: { errors: { base: [ I18n.t("frontend.admin.units.not_found") ] } }
  end

  def set_restorable_unit
    @unit = policy_scope(Unit)
      .with_deleted
      .where(residential_property: @residential_property)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_residential_properties_path,
                inertia: { errors: { base: [ I18n.t("frontend.admin.units.not_found") ] } }
  end
end
