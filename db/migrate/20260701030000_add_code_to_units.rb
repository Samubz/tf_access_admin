# frozen_string_literal: true

# Adds the machine-readable, system-derived +code+ to units
# (hierarchical-code-generation). Nullable; derived on every create going
# forward. Tenant-scoped partial unique indexes mirror the two
# normalized_identifier contexts: sectioned units and root-level units.
class AddCodeToUnits < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :units, :code, :string

    add_index :units,
              %i[organization_id residential_property_id property_section_id code],
              unique: true,
              algorithm: :concurrently,
              where: "deleted_at IS NULL AND property_section_id IS NOT NULL AND code IS NOT NULL",
              name: "idx_units_unique_code_in_section"

    add_index :units,
              %i[organization_id residential_property_id code],
              unique: true,
              algorithm: :concurrently,
              where: "deleted_at IS NULL AND property_section_id IS NULL AND code IS NOT NULL",
              name: "idx_units_unique_code_in_property_root"
  end
end
