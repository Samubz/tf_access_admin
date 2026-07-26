# frozen_string_literal: true

require "test_helper"

class Admin::People::BulkImportsControllerTest < ActionDispatch::IntegrationTest
  include InertiaTestHelper
  include UserTestHelper
  include ActionMailer::TestHelper

  setup do
    @organization = organizations(:one)
    @other_organization = organizations(:two)
    ActsAsTenant.current_tenant = @organization

    @tenant_admin = create_user_for_organization(
      organization: @organization,
      email: "people-bulk-admin@example.test",
      role: AvailableRoles::TENANT_ADMIN
    )
    @client = create_user_for_organization(
      organization: @organization,
      email: "people-bulk-client@example.test",
      role: AvailableRoles::CLIENT
    )

    @bulk_import = BulkImport.create!(
      organization: @organization,
      created_by: @tenant_admin,
      import_type: BulkImport::IMPORT_TYPES[:users],
      status: "validated"
    )

    @other_bulk_import = ActsAsTenant.with_tenant(@other_organization) do
      other_admin = create_user_for_organization(
        organization: @other_organization,
        email: "other-org-bulk-admin@example.test",
        role: AvailableRoles::TENANT_ADMIN
      )
      BulkImport.create!(
        organization: @other_organization,
        created_by: other_admin,
        import_type: BulkImport::IMPORT_TYPES[:users],
        status: "validated"
      )
    end
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "authorized admin can fetch status of a people bulk import" do
    sign_in_as(@tenant_admin)

    get status_admin_people_bulk_import_path(@bulk_import)

    assert_response :success
  end

  test "user without manage_people cannot access a people bulk import" do
    sign_in_as(@client)

    get status_admin_people_bulk_import_path(@bulk_import)

    assert_response :not_found
  end

  test "bulk import belonging to another organization is not found" do
    sign_in_as(@tenant_admin)

    get status_admin_people_bulk_import_path(@other_bulk_import)

    assert_response :not_found
  end

  test "authorized admin can trigger invitations for classified rows" do
    sign_in_as(@tenant_admin)
    row = build_requires_invitation_row!(document_number: "16.101.010-1")

    assert_enqueued_emails 1 do
      post trigger_invitations_admin_people_bulk_import_path(@bulk_import)
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["counts"]["triggered"]
    assert row.reload.target_record.present?
  end

  test "trigger_invitations scopes to the given row_ids" do
    sign_in_as(@tenant_admin)
    row1 = build_requires_invitation_row!(document_number: "17.101.010-1", row_number: 1)
    row2 = build_requires_invitation_row!(document_number: "18.101.010-1", row_number: 2)

    post trigger_invitations_admin_people_bulk_import_path(@bulk_import), params: { row_ids: [ row1.id ] }

    assert_response :success
    assert row1.reload.target_record.present?
    assert_nil row2.reload.target_record
  end

  test "user without manage_people cannot trigger invitations" do
    sign_in_as(@client)
    build_requires_invitation_row!(document_number: "19.101.010-1")

    post trigger_invitations_admin_people_bulk_import_path(@bulk_import)

    assert_response :not_found
  end

  test "trigger_invitations on another organization's bulk import is not found" do
    sign_in_as(@tenant_admin)

    post trigger_invitations_admin_people_bulk_import_path(@other_bulk_import)

    assert_response :not_found
  end

  private

  def build_requires_invitation_row!(document_number:, row_number: 1)
    Person.new(
      organization: @organization, display_name: "Pending Trigger",
      person_type: PersonTypes::NATURAL, status: PersonStatuses::ACTIVE
    ).tap { |p| p.document_number = document_number }.save!

    @bulk_import.rows.create!(
      row_number: row_number,
      raw_payload: { "first_name" => "Pending", "last_name" => "Trigger", "document_number" => document_number },
      normalized_payload: { "first_name" => "Pending", "last_name" => "Trigger", "document_number" => document_number },
      validation_status: BulkImportRow::VALIDATION_STATUSES[:valid],
      import_status: BulkImportRow::IMPORT_STATUSES[:skipped],
      onboarding_classification: BulkImportRow::ONBOARDING_CLASSIFICATIONS[:requires_invitation]
    )
  end

  def sign_in_as(user)
    host! "#{@organization.subdomain}.example.com"
    post user_session_path, params: { user: { email: user.email, password: "Password1@" } }
  end
end
