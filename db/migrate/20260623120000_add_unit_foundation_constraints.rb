# frozen_string_literal: true

# improve-units-foundation §4: normalized-identifier backfill, partial uniqueness
# indexes (with/without section), area check, tenant lookup indexes, FK
# verification and optional organization↔property composite FK.
#
# Type/status check constraints are intentionally deferred until legacy audit
# completes (§4.8).
class AddUnitFoundationConstraints < ActiveRecord::Migration[8.1]
  WITH_SECTION_INDEX = "index_units_on_org_property_section_normalized_when_section"
  WITHOUT_SECTION_INDEX = "index_units_on_org_property_normalized_when_no_section"
  LEGACY_COMBINED_INDEX = "idx_units_unique_normalized_id_per_context"
  LOOKUP_INDEX = "idx_units_on_org_property_normalized_identifier_lookup"
  ORG_PROPERTY_UNIQUE_INDEX = "idx_residential_properties_organization_id_id"
  ORG_PROPERTY_FK = "fk_units_organization_residential_property_coherent"

  def up
    return unless table_exists?(:units)

    backfill_normalized_identifiers!
    reconcile_organization_from_property!
    assert_no_blocking_duplicates!

    replace_uniqueness_indexes!
    add_area_check_constraint!
    add_normalized_identifier_lookup_index!
    verify_required_constraints!
    verify_foreign_keys!
    add_organization_property_coherence!
  end

  def down
    remove_foreign_key :units, name: ORG_PROPERTY_FK, if_exists: true
    remove_index :residential_properties, name: ORG_PROPERTY_UNIQUE_INDEX, if_exists: true
    remove_index :units, name: LOOKUP_INDEX, if_exists: true
    remove_check_constraint :units, name: "units_area_m2_positive", if_exists: true
    remove_index :units, name: WITH_SECTION_INDEX, if_exists: true
    remove_index :units, name: WITHOUT_SECTION_INDEX, if_exists: true

    return unless table_exists?(:units)
    return if index_exists?(:units, LEGACY_COMBINED_INDEX)

    add_index :units,
              %i[organization_id residential_property_id property_section_id normalized_identifier],
              unique: true,
              where: "(deleted_at IS NULL)",
              name: LEGACY_COMBINED_INDEX
  end

  private

  # §4.1: Ruby canonical normalization (Unicode-safe) before enforcing indexes.
  def backfill_normalized_identifiers!
    say_with_time "Backfilling units.normalized_identifier via Units::NormalizeIdentifier" do
      Unit.unscoped.find_each do |unit|
        next if unit.identifier.blank?

        result = Units::NormalizeIdentifier.call(unit.identifier)
        next unless result

        updates = {}
        updates[:identifier] = result.identifier if unit.identifier != result.identifier
        if unit.normalized_identifier != result.normalized_identifier
          updates[:normalized_identifier] = result.normalized_identifier
        end
        unit.update_columns(updates.merge(updated_at: Time.current)) if updates.any?
      end
    end
  end

  # §4.4: align organization with the trusted property before composite FK.
  def reconcile_organization_from_property!
    execute(<<~SQL.squish)
      UPDATE units AS u
      SET organization_id = rp.organization_id,
          updated_at = CURRENT_TIMESTAMP
      FROM residential_properties AS rp
      WHERE u.residential_property_id = rp.id
        AND u.organization_id IS DISTINCT FROM rp.organization_id
    SQL
  end

  def assert_no_blocking_duplicates!
    with_section = duplicate_rows(<<~SQL.squish)
      SELECT organization_id, residential_property_id, property_section_id, normalized_identifier,
             COUNT(*) AS duplicate_count
      FROM units
      WHERE deleted_at IS NULL
        AND property_section_id IS NOT NULL
      GROUP BY 1, 2, 3, 4
      HAVING COUNT(*) > 1
      LIMIT 5
    SQL

    without_section = duplicate_rows(<<~SQL.squish)
      SELECT organization_id, residential_property_id, normalized_identifier,
             COUNT(*) AS duplicate_count
      FROM units
      WHERE deleted_at IS NULL
        AND property_section_id IS NULL
      GROUP BY 1, 2, 3
      HAVING COUNT(*) > 1
      LIMIT 5
    SQL

    return if with_section.empty? && without_section.empty?

    raise ActiveRecord::IrreversibleMigration,
          "Cannot add unit uniqueness indexes: resolve duplicate active identifiers first " \
          "(with_section=#{with_section.size}, without_section=#{without_section.size})."
  end

  # §4.5/§4.6/§4.10: two partial unique indexes so NULL section contexts dedupe
  # correctly under acts_as_paranoid (deleted_at IS NULL).
  def replace_uniqueness_indexes!
    remove_index :units, name: LEGACY_COMBINED_INDEX, if_exists: true
    remove_index :units, name: WITH_SECTION_INDEX, if_exists: true
    remove_index :units, name: WITHOUT_SECTION_INDEX, if_exists: true

    add_index :units,
              %i[organization_id residential_property_id property_section_id normalized_identifier],
              unique: true,
              where: "(property_section_id IS NOT NULL AND deleted_at IS NULL)",
              name: WITH_SECTION_INDEX

    add_index :units,
              %i[organization_id residential_property_id normalized_identifier],
              unique: true,
              where: "(property_section_id IS NULL AND deleted_at IS NULL)",
              name: WITHOUT_SECTION_INDEX
  end

  # §4.7
  def add_area_check_constraint!
    return if check_constraint_exists?(:units, name: "units_area_m2_positive")

    add_check_constraint :units,
                         "area_m2 IS NULL OR area_m2 > 0",
                         name: "units_area_m2_positive"
    validate_check_constraint :units, name: "units_area_m2_positive"
  end

  # §4.9: tenant/property scoped normalized lookup among active rows.
  def add_normalized_identifier_lookup_index!
    return if index_exists?(:units, name: LOOKUP_INDEX)

    add_index :units,
              %i[organization_id residential_property_id normalized_identifier],
              name: LOOKUP_INDEX,
              where: "(deleted_at IS NULL)"
  end

  # §4.3
  def verify_required_constraints!
    %i[
      organization_id residential_property_id identifier normalized_identifier
      unit_type status metadata
    ].each do |column|
      next unless column_exists?(:units, column)
      next unless connection.columns(:units).find { |c| c.name == column.to_s }&.null

      change_column_null :units, column, false
    end

    change_column_default :units, :metadata, from: nil, to: {} if column_exists?(:units, :metadata)
  end

  # §4.2
  def verify_foreign_keys!
    {
      organizations: :organization_id,
      residential_properties: :residential_property_id,
      property_sections: :property_section_id
    }.each do |table, column|
      next unless column_exists?(:units, column)

      add_foreign_key :units, table unless foreign_key_exists?(:units, table)
    end
  end

  # §4.4: composite FK so units.organization_id always matches the property org.
  def add_organization_property_coherence!
    unless index_exists?(:residential_properties, %i[organization_id id], name: ORG_PROPERTY_UNIQUE_INDEX)
      add_index :residential_properties,
                %i[organization_id id],
                unique: true,
                name: ORG_PROPERTY_UNIQUE_INDEX
    end

    return if foreign_key_exists?(:units, name: ORG_PROPERTY_FK)

    add_foreign_key :units,
                    :residential_properties,
                    column: %i[organization_id residential_property_id],
                    primary_key: %i[organization_id id],
                    name: ORG_PROPERTY_FK
  end

  def duplicate_rows(sql)
    connection.select_all(sql).to_a
  end
end
