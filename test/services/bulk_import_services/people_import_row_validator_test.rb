# frozen_string_literal: true

require "test_helper"

module BulkImportServices
  class PeopleImportRowValidatorTest < ActiveSupport::TestCase
    setup do
      @organization = organizations(:one)
      ActsAsTenant.current_tenant = @organization
      @user = users(:one)
      @bulk_import = BulkImport.new(
        organization: @organization,
        created_by: @user,
        import_type: BulkImport::IMPORT_TYPES[:users],
        metadata: { "options" => { "import_mode" => "create_skip_duplicates" } }
      )
      @context = PeopleImportValidationContext.new(bulk_import: @bulk_import)
    end

    teardown do
      ActsAsTenant.current_tenant = nil
    end

    def validate(payload)
      row = UnitsSpreadsheetReader::ParsedRow.new(row_number: 1, raw_payload: payload)
      PeopleImportRowValidator.call(parsed_row: row, context: @context)
    end

    def valid_payload(overrides = {})
      {
        "first_name" => "Ana",
        "last_name" => "Torres",
        "document_number" => "12345678",
        "phone" => "+56 9 1234 5678",
        "email" => "ana.torres@example.test",
        "birthdate" => "15/06/1990"
      }.merge(overrides)
    end

    test "a fully valid row is marked valid" do
      result = validate(valid_payload)

      assert_equal BulkImportRow::VALIDATION_STATUSES[:valid], result.validation_status
      assert_empty result.validation_errors
    end

    test "missing required field is an error" do
      result = validate(valid_payload("first_name" => nil))

      assert_equal BulkImportRow::VALIDATION_STATUSES[:error], result.validation_status
      assert_equal "first_name", result.validation_errors.first["field"]
    end

    test "phone in an unexpected format is not an error" do
      result = validate(valid_payload("phone" => "abc-not-a-phone"))

      assert_equal BulkImportRow::VALIDATION_STATUSES[:valid], result.validation_status
    end

    test "invalid email format is an error" do
      result = validate(valid_payload("email" => "not-an-email"))

      assert_equal BulkImportRow::VALIDATION_STATUSES[:error], result.validation_status
      assert_equal "email", result.validation_errors.first["field"]
    end

    test "birthdate not in DD/MM/YYYY format is an error" do
      result = validate(valid_payload("birthdate" => "1990-06-15"))

      assert_equal BulkImportRow::VALIDATION_STATUSES[:error], result.validation_status
      assert_equal "invalid_format", result.validation_errors.first["code"]
    end

    test "birthdate with DD-MM-YYYY format is accepted" do
      result = validate(valid_payload("birthdate" => "15-06-1990"))

      assert_equal BulkImportRow::VALIDATION_STATUSES[:valid], result.validation_status
      assert_empty result.validation_errors
      assert_equal "1990-06-15", result.normalized_payload["birthdate"]
    end

    test "impossible birthdate is an error and is not coerced" do
      result = validate(valid_payload("birthdate" => "31/02/1990"))

      assert_equal BulkImportRow::VALIDATION_STATUSES[:error], result.validation_status
      assert_equal "impossible", result.validation_errors.first["code"]
    end

    test "future birthdate is an error" do
      future = (Date.current + 1).strftime("%d/%m/%Y")
      result = validate(valid_payload("birthdate" => future))

      assert_equal BulkImportRow::VALIDATION_STATUSES[:error], result.validation_status
      assert_equal "future", result.validation_errors.first["code"]
    end

    test "duplicate document within the file is marked duplicate and skipped by default" do
      validate(valid_payload("document_number" => "99999999"))
      result = validate(valid_payload("document_number" => "99999999", "email" => "other@example.test"))

      assert_equal BulkImportRow::VALIDATION_STATUSES[:duplicate], result.validation_status
      assert_equal BulkImportRow::IMPORT_STATUSES[:skipped], result.import_status
    end

    test "duplicate email within the file is marked duplicate and skipped by default" do
      validate(valid_payload("email" => "same@example.test"))
      result = validate(valid_payload("email" => "same@example.test", "document_number" => "11112222"))

      assert_equal BulkImportRow::VALIDATION_STATUSES[:duplicate], result.validation_status
    end

    test "existing organization identity by document is detected as duplicate" do
      existing = Person.create!(
        organization: @organization,
        first_name: "Existing",
        last_name: "Person",
        person_type: PersonTypes::NATURAL,
        status: PersonStatuses::ACTIVE
      )
      existing.document_number = "55556666"
      existing.save!

      context = PeopleImportValidationContext.new(bulk_import: @bulk_import)
      row = UnitsSpreadsheetReader::ParsedRow.new(
        row_number: 1,
        raw_payload: valid_payload("document_number" => "55556666")
      )
      result = PeopleImportRowValidator.call(parsed_row: row, context: context)

      assert_equal BulkImportRow::VALIDATION_STATUSES[:duplicate], result.validation_status
    end

    test "cross-organization identity does not conflict" do
      other_organization = organizations(:two)
      ActsAsTenant.with_tenant(other_organization) do
        other_person = Person.create!(
          organization: other_organization,
          first_name: "Other",
          last_name: "Org",
          person_type: PersonTypes::NATURAL,
          status: PersonStatuses::ACTIVE
        )
        other_person.document_number = "77778888"
        other_person.save!
      end

      result = validate(valid_payload("document_number" => "77778888"))

      assert_equal BulkImportRow::VALIDATION_STATUSES[:valid], result.validation_status
    end
  end
end
