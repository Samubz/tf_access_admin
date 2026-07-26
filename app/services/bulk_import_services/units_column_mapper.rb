# frozen_string_literal: true

# TODO: Translate to English and Portuguese
module BulkImportServices
  class UnitsColumnMapper
    TARGET_FIELDS = [
      { key: "unit_identifier", required: true },
      { key: "unit_type", required: true },
      { key: "display_name", required: false },
      { key: "area_m2", required: false },
      { key: "status", required: false },
      { key: "owner_document", required: false },
      { key: "owner_email", required: false },
      { key: "owner_first_name", required: false },
      { key: "owner_last_name", required: false },
      { key: "ownership_percentage", required: false }
    ].freeze

    HEADER_ALIASES = {
      "numero" => "unit_identifier",
      "número" => "unit_identifier",
      "identificador" => "unit_identifier",
      "numero_identificador" => "unit_identifier",
      "número_identificador" => "unit_identifier",
      "numero_/_identificador" => "unit_identifier",
      "tipo" => "unit_type",
      "tipo_unidad" => "unit_type",
      "unit_type" => "unit_type",
      "nombre" => "display_name",
      "display_name" => "display_name",
      "area" => "area_m2",
      "area_m2" => "area_m2",
      "estado" => "status",
      "status" => "status",
      "email_propietario" => "owner_email",
      "owner_email" => "owner_email",
      "correo_propietario" => "owner_email",
      "documento_propietario" => "owner_document",
      "owner_document" => "owner_document",
      "documento" => "owner_document",
      "dni_propietario" => "owner_document",
      "cedula_propietario" => "owner_document",
      "owner_first_name" => "owner_first_name",
      "primer_nombre_propietario" => "owner_first_name",
      "owner_last_name" => "owner_last_name",
      "apellido" => "owner_last_name",
      "apellidos" => "owner_last_name",
      "apellido_propietario" => "owner_last_name",
      "ownership_percentage" => "ownership_percentage",
      "porcentaje_propiedad" => "ownership_percentage",
      "porcentaje_de_propiedad" => "ownership_percentage",
      "porcentaje" => "ownership_percentage"
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
