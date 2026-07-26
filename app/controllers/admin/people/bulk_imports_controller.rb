# frozen_string_literal: true

class Admin::People::BulkImportsController < AdminController
  before_action :set_bulk_import, only: %i[update validate rows confirm status report trigger_invitations]

  def create
    authorize BulkImport, :create_people_import?

    bulk_import = BulkImportServices::CreatePeopleImport.call(
      organization: ActsAsTenant.current_tenant,
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

    bulk_import = BulkImportServices::UpdatePeopleImport.call(
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

    bulk_import = BulkImportServices::ValidatePeopleImport.call(bulk_import: @bulk_import)
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

    bulk_import = BulkImportServices::ConfirmPeopleImport.call(
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
    filename = "bulk-people-import-#{@bulk_import.id}-report.csv"

    send_data csv,
              type: "text/csv; charset=utf-8",
              disposition: "attachment",
              filename: filename
  end

  def trigger_invitations
    authorize @bulk_import, :trigger_invitations?

    result = BulkImportServices::TriggerRowInvitations.call(
      bulk_import: @bulk_import,
      row_ids: trigger_invitations_params[:row_ids],
      requested_by_person: current_user.person_for(ActsAsTenant.current_tenant)
    )

    render json: {
      counts: {
        triggered: result.counts[:triggered] || 0,
        conflicted: result.counts[:conflicted] || 0,
        skipped: result.counts[:skipped] || 0,
        failed: result.counts[:failed] || 0
      },
      results: result.results
    }
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

  def trigger_invitations_params
    params.permit(row_ids: [])
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
    params.require(:bulk_import).permit(:file, :import_mode)
  end

  def bulk_import_update_params
    params.require(:bulk_import).permit(:file, :selected_sheet, :import_mode)
  end

  def options_from_params
    bulk_import_params.slice(:import_mode).compact
  end

  def options_from_update_params
    bulk_import_update_params.slice(:import_mode).compact
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

  def set_bulk_import
    @bulk_import = policy_scope(BulkImport)
      .where(import_type: BulkImport::IMPORT_TYPES[:users])
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: { base: [ I18n.t("frontend.admin.bulk_imports.not_found") ] } },
           status: :not_found
  end
end
