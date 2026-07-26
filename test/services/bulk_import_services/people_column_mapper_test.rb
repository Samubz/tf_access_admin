# frozen_string_literal: true

require "test_helper"

module BulkImportServices
  class PeopleColumnMapperTest < ActiveSupport::TestCase
    test "maps required fields from template headers" do
      headers = %w[first_name last_name document_number phone email birthdate]

      mappings = PeopleColumnMapper.call(headers:)
      by_target = mappings.index_by { |mapping| mapping["target"] }

      assert_equal "first_name", by_target["first_name"]["source"]
      assert_equal "last_name", by_target["last_name"]["source"]
      assert_equal "document_number", by_target["document_number"]["source"]
      assert_equal "phone", by_target["phone"]["source"]
      assert_equal "email", by_target["email"]["source"]
      assert_equal "birthdate", by_target["birthdate"]["source"]
      assert by_target.values.all? { |mapping| mapping["matched"] }
    end

    test "maps localized Spanish header aliases" do
      headers = %w[nombre apellido documento telefono correo fecha_nacimiento]

      mappings = PeopleColumnMapper.call(headers:)
      by_target = mappings.index_by { |mapping| mapping["target"] }

      assert_equal "nombre", by_target["first_name"]["source"]
      assert_equal "apellido", by_target["last_name"]["source"]
      assert_equal "documento", by_target["document_number"]["source"]
      assert_equal "telefono", by_target["phone"]["source"]
      assert_equal "correo", by_target["email"]["source"]
      assert_equal "fecha_nacimiento", by_target["birthdate"]["source"]
    end

    test "marks required target unmatched when no header maps to it" do
      headers = %w[first_name last_name document_number]

      mappings = PeopleColumnMapper.call(headers:)
      by_target = mappings.index_by { |mapping| mapping["target"] }

      refute by_target["email"]["matched"]
      assert by_target["email"]["required"]
      assert_nil by_target["email"]["source"]
    end
  end
end
