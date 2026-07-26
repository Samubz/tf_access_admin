# frozen_string_literal: true

# improve-property-foundation §1: status check constraint, normalized-name column,
# tenant-scoped unique index for non-deleted normalized names, and verification of
# the required NOT NULL columns / FK on residential_properties.
class AddPropertyFoundationConstraints < ActiveRecord::Migration[8.1]
  NORMALIZE_SQL = "lower(regexp_replace(btrim(name), '\\s+', ' ', 'g'))"

  def up
    # 1.4 normalized name column for case-insensitive uniqueness.
    add_column :residential_properties, :normalized_name, :string

    # Backfill existing rows using the same expression the model will apply.
    execute(<<~SQL.squish)
      UPDATE residential_properties
      SET normalized_name = #{NORMALIZE_SQL}
      WHERE name IS NOT NULL
    SQL

    change_column_null :residential_properties, :normalized_name, false

    # 1.5 unique normalized name per organization among non-deleted properties.
    add_index :residential_properties,
              %i[organization_id normalized_name],
              unique: true,
              where: "(deleted_at IS NULL)",
              name: "idx_residential_properties_unique_normalized_name_per_org"

    # 1.3 allowed status values.
    add_check_constraint :residential_properties,
                         "status IN ('active', 'inactive', 'archived')",
                         name: "residential_properties_status_allowed"

    # 1.6 verify required NOT NULL columns and the organization FK exist.
    verify_required_constraints!
  end

  def down
    remove_check_constraint :residential_properties,
                            name: "residential_properties_status_allowed",
                            if_exists: true
    remove_index :residential_properties,
                 name: "idx_residential_properties_unique_normalized_name_per_org",
                 if_exists: true
    remove_column :residential_properties, :normalized_name, if_exists: true
  end

  private

  def verify_required_constraints!
    %i[organization_id name property_type status].each do |column|
      next unless column_exists?(:residential_properties, column)
      next unless connection.columns(:residential_properties).find { |c| c.name == column.to_s }&.null

      change_column_null :residential_properties, column, false
    end

    unless foreign_key_exists?(:residential_properties, :organizations)
      add_foreign_key :residential_properties, :organizations
    end
  end
end
