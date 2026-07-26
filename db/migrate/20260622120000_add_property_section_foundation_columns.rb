# frozen_string_literal: true

# improve-property-sections §1: normalized-name column, lifecycle status,
# type/status check constraints, tenant-scoped sibling-name unique indexes
# (root and child contexts), and a traversal/order index.
class AddPropertySectionFoundationColumns < ActiveRecord::Migration[8.1]
  NORMALIZE_SQL = "lower(regexp_replace(btrim(name), '\\s+', ' ', 'g'))"

  # Canonical target catalog plus legacy values kept transitionally. The legacy
  # values (parking/storage/commercial/amenities/entrance/garden) still live in
  # SectionTypes and existing data; mapping/narrowing is handled in §2, so the
  # constraint accepts both sets for now without breaking the current module.
  ALLOWED_SECTION_TYPES = %w[
    building tower floor block stage sector parking_area storage_area other
    parking storage commercial amenities entrance garden
  ].freeze

  def up
    # 1.2 normalized name + tenant-safe backfill.
    add_column :property_sections, :normalized_name, :string
    execute(<<~SQL.squish)
      UPDATE property_sections
      SET normalized_name = #{NORMALIZE_SQL}
      WHERE name IS NOT NULL
    SQL
    change_column_null :property_sections, :normalized_name, false

    # 1.3 lifecycle status.
    add_column :property_sections, :status, :string, null: false, default: "active"

    # 1.4 type and status constraints.
    add_check_constraint :property_sections,
                         "status IN ('active', 'inactive', 'archived')",
                         name: "property_sections_status_allowed"
    add_check_constraint :property_sections,
                         section_type_constraint_sql,
                         name: "property_sections_section_type_allowed"

    # 1.5 + 1.6 sibling-name uniqueness. Two partial indexes so root sections
    # (parent_id IS NULL) are deduplicated correctly — Postgres treats NULLs as
    # distinct, so a single index over parent_id would not catch duplicate roots.
    add_index :property_sections,
              %i[organization_id residential_property_id normalized_name],
              unique: true,
              where: "(parent_id IS NULL AND deleted_at IS NULL)",
              name: "idx_property_sections_unique_root_name"
    add_index :property_sections,
              %i[organization_id residential_property_id parent_id normalized_name],
              unique: true,
              where: "(parent_id IS NOT NULL AND deleted_at IS NULL)",
              name: "idx_property_sections_unique_child_name"

    # 1.7 traversal/order index for siblings within a property/parent.
    add_index :property_sections,
              %i[residential_property_id parent_id position],
              name: "idx_property_sections_property_parent_position"

    verify_required_constraints!
  end

  def down
    remove_index :property_sections, name: "idx_property_sections_property_parent_position", if_exists: true
    remove_index :property_sections, name: "idx_property_sections_unique_child_name", if_exists: true
    remove_index :property_sections, name: "idx_property_sections_unique_root_name", if_exists: true
    remove_check_constraint :property_sections, name: "property_sections_section_type_allowed", if_exists: true
    remove_check_constraint :property_sections, name: "property_sections_status_allowed", if_exists: true
    remove_column :property_sections, :status, if_exists: true
    remove_column :property_sections, :normalized_name, if_exists: true
  end

  private

  def section_type_constraint_sql
    list = ALLOWED_SECTION_TYPES.map { |type| "'#{type}'" }.join(", ")
    "section_type IN (#{list})"
  end

  # 1.6/1.x integrity: confirm the required NOT NULL columns and FKs exist.
  def verify_required_constraints!
    %i[organization_id residential_property_id name section_type].each do |column|
      next unless column_exists?(:property_sections, column)
      next unless connection.columns(:property_sections).find { |c| c.name == column.to_s }&.null

      change_column_null :property_sections, column, false
    end

    unless foreign_key_exists?(:property_sections, :organizations)
      add_foreign_key :property_sections, :organizations
    end
    unless foreign_key_exists?(:property_sections, :residential_properties)
      add_foreign_key :property_sections, :residential_properties
    end
  end
end
