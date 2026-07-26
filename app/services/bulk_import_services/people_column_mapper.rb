# frozen_string_literal: true

module BulkImportServices
  class PeopleColumnMapper
    TARGET_FIELDS = [
      { key: "first_name", required: true },
      { key: "last_name", required: true },
      { key: "document_number", required: true },
      { key: "phone", required: true },
      { key: "email", required: true },
      { key: "birthdate", required: true }
    ].freeze

    HEADER_ALIASES = {
      "nombre" => "first_name",
      "nombres" => "first_name",
      "primer_nombre" => "first_name",
      "first_name" => "first_name",
      "apellido" => "last_name",
      "apellidos" => "last_name",
      "last_name" => "last_name",
      "documento" => "document_number",
      "dni" => "document_number",
      "cedula" => "document_number",
      "rut" => "document_number",
      "document_number" => "document_number",
      "telefono" => "phone",
      "teléfono" => "phone",
      "celular" => "phone",
      "phone" => "phone",
      "correo" => "email",
      "correo_electronico" => "email",
      "email" => "email",
      "fecha_de_nacimiento" => "birthdate",
      "fecha_nacimiento" => "birthdate",
      "nacimiento" => "birthdate",
      "birthdate" => "birthdate"
    }.freeze

    def self.call(headers:)
      new(headers:).call
    end

    def initialize(headers:)
      @headers = headers
    end

    def call
      used_sources = {}

      TARGET_FIELDS.map do |field|
        source = match_source_for(field[:key], used_sources)
        used_sources[source] = true if source

        {
          "source" => source,
          "target" => field[:key],
          "required" => field[:required],
          "matched" => source.present?
        }
      end
    end

    private

    def match_source_for(target_key, used_sources)
      @headers.find do |header|
        next if used_sources[header]

        normalize_header(header) == target_key || HEADER_ALIASES[normalize_header(header)] == target_key
      end
    end

    def normalize_header(header)
      header.to_s.strip.downcase.gsub(/\s+/, "_").gsub(/[^\w]/, "_").squeeze("_").delete_suffix("_")
    end
  end
end
