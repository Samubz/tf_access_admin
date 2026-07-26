# frozen_string_literal: true

namespace :domain_codes do
  desc "DEV/TEST ONLY: hard-delete every residential property and all records " \
       "referencing them (directly, or via their units/sections). No backfill."
  task purge_properties: :environment do
    abort("Refusing to run in production.") if Rails.env.production?

    conn = ActiveRecord::Base.connection

    property_ids = conn.select_values("SELECT id FROM residential_properties")
    if property_ids.empty?
      puts "No residential properties to purge."
      next
    end

    unit_ids = ids_referencing(conn, "units", "residential_property_id", property_ids)
    section_ids = ids_referencing(conn, "property_sections", "residential_property_id", property_ids)

    # Column → id-set map applied to any table that carries one of these FKs. This
    # is schema-driven so a newly added dependent table is covered automatically.
    fk_targets = {
      "residential_property_id" => property_ids,
      "unit_id" => unit_ids,
      "property_section_id" => section_ids
    }

    deleted = Hash.new(0)

    conn.disable_referential_integrity do
      conn.tables.each do |table|
        next if table == "residential_properties"

        columns = conn.columns(table).map(&:name)
        fk_targets.each do |column, ids|
          next unless columns.include?(column)
          next if ids.empty?

          deleted[table] += delete_by(conn, table, column, ids)
        end
      end

      deleted["residential_properties"] += conn.delete("DELETE FROM residential_properties")
    end

    deleted.reject { |_, n| n.zero? }.sort.each { |table, n| puts format("  %-32s %d", table, n) }
    puts "Purge complete."
  end
end

def ids_referencing(conn, table, column, ids)
  conn.select_values(
    "SELECT id FROM #{conn.quote_table_name(table)} " \
    "WHERE #{conn.quote_column_name(column)} IN (#{quote_id_list(conn, ids)})"
  )
end

def delete_by(conn, table, column, ids)
  conn.delete(
    "DELETE FROM #{conn.quote_table_name(table)} " \
    "WHERE #{conn.quote_column_name(column)} IN (#{quote_id_list(conn, ids)})"
  )
end

def quote_id_list(conn, ids)
  ids.map { |id| conn.quote(id) }.join(", ")
end
