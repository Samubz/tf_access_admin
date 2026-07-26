# frozen_string_literal: true

class Admin::ResidentialProperties::BulkImportsController < AdminController
  before_action :set_residential_property
  before_action :set_property_section, only: :create
  before_action :set_bulk_import, only: %i[update validate rows confirm status report]

  def create
    authorize BulkImport

    bulk_import = BulkImportServices::CreateUnitsImport.call(
      residential_property: @residential_property,
      property_section: @property_section,
      created_by: current_user,
      file: bulk_import_params.require(:file),
      options: options_from_params
    )

    render_bulk_import(bulk_import, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e.record)
  end

  def update
    authorize @bulk_import

    bulk_import = BulkImportServices::UpdateUnitsImport.call(
      bulk_import: @bulk_import,
      file: bulk_import_update_params[:file],
      selected_sheet: bulk_import_update_params[:selected_sheet],
      options: options_from_update_params
    )

    render_bulk_import(bulk_import)
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e.record)
  end

  def validate
    authorize @bulk_import, :validate?

    bulk_import = BulkImportServices::ValidateUnitsImport.call(bulk_import: @bulk_import)
    preview = preview_rows_result(bulk_import)

    render json: preview_response(bulk_import, preview)
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e.record)
  end

  def rows
    authorize @bulk_import, :rows?

    preview = preview_rows_result(@bulk_import)
    render json: rows_response(preview)
  end

  def confirm
    authorize @bulk_import, :confirm?

    bulk_import = BulkImportServices::ConfirmUnitsImport.call(
      bulk_import: @bulk_import,
      import_valid_rows_only: confirm_params[:import_valid_rows_only]
    )

    render json: {
      bulk_import: Admin::BulkImportSerializer.new(bulk_import).as_json,
      status: bulk_import.status
    }
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e.record)
  end

  def status
    authorize @bulk_import, :status?

    payload = BulkImportServices::BulkImportImportStatus.call(
      bulk_import: @bulk_import,
      logs_after: status_params[:logs_after]
    )

    render json: payload
  end

  def report
    authorize @bulk_import, :report?

    csv = BulkImportServices::BulkImportReport.call(bulk_import: @bulk_import)
    filename = "bulk-import-#{@bulk_import.id}-report.csv"

    send_data csv,
              type: "text/csv; charset=utf-8",
              disposition: "attachment",
              filename: filename
  end

  private

  def preview_rows_result(bulk_import)
    BulkImportServices::ListBulkImportRows.call(
      bulk_import: bulk_import,
      page: rows_params[:page],
      per_page: rows_params[:per_page],
      filter: rows_params[:filter],
      search: rows_params[:search]
    )
  end

  def rows_params
    params.permit(:page, :per_page, :filter, :search)
  end

  def confirm_params
    params.permit(:import_valid_rows_only)
  end

  def status_params
    params.permit(:logs_after)
  end

  def preview_response(bulk_import, preview)
    rows_response(preview).merge(
      bulk_import: Admin::BulkImportSerializer.new(bulk_import).as_json
    )
  end

  def rows_response(preview)
    {
      rows: preview.rows.map { |row| Admin::BulkImportRowSerializer.new(row).as_json },
      pagination: preview.pagination,
      summary: preview.summary
    }
  end

  def bulk_import_params
    params.require(:bulk_import).permit(
      :file,
      :property_section_id,
      :import_type,
      :import_mode,
      :owner_import_mode
    )
  end

  def bulk_import_update_params
    params.require(:bulk_import).permit(
      :file,
      :selected_sheet,
      :import_mode,
      :property_section_id,
      :owner_import_mode
    )
  end

  def options_from_params
    bulk_import_params.slice(:import_mode, :property_section_id, :owner_import_mode).compact
  end

  def options_from_update_params
    bulk_import_update_params.slice(:import_mode, :property_section_id, :owner_import_mode).compact
  end

  def render_bulk_import(bulk_import, status: :ok)
    render json: {
      bulk_import: Admin::BulkImportSerializer.new(bulk_import).as_json
    }, status: status
  end

  def render_validation_errors(record)
    render json: {
      errors: serialize_inertia_errors(record)
    }, status: :unprocessable_entity
  end

  def set_residential_property
    @residential_property = policy_scope(ResidentialProperty).find(params[:residential_property_id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: { base: [ I18n.t("frontend.admin.residential_properties.not_found") ] } },
           status: :not_found
  end

  def set_property_section
    section_id = bulk_import_params[:property_section_id]
    return render_property_section_required if section_id.blank?

    @property_section = policy_scope(PropertySection)
      .where(residential_property: @residential_property)
      .find(section_id)
  rescue ActiveRecord::RecordNotFound
    render json: { errors: { base: [ I18n.t("frontend.admin.property_sections.not_found") ] } },
           status: :not_found
  end

  def set_bulk_import
    @bulk_import = policy_scope(BulkImport)
      .where(residential_property: @residential_property)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: { base: [ I18n.t("frontend.admin.bulk_imports.not_found") ] } },
           status: :not_found
  end

  def render_property_section_required
    render json: {
      errors: { property_section_id: [ I18n.t("frontend.admin.bulk_imports.property_section_required") ] }
    }, status: :unprocessable_entity
  end
end
