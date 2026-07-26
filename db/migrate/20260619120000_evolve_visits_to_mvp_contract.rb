# frozen_string_literal: true

# Evolves legacy +visits+ toward the MVP contract: Person identities, User actors,
# denormalized location, MVP statuses, and operational metadata columns.
class EvolveVisitsToMvpContract < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_mvp_columns!
    backfill_mvp_columns! if legacy_columns_present?
    remove_incompatible_visits! if column_exists?(:visits, :visitor_person_id)

    enforce_not_nulls! if column_exists?(:visits, :visitor_person_id)
    remove_legacy_visit_columns!
    replace_visit_indexes!
    replace_validity_check_constraint!
  end

  def down
    remove_check_constraint :visits, name: "visits_validity_range_valid", if_exists: true

    remove_index :visits, name: "index_visits_on_org_property_operational_statuses", if_exists: true
    remove_index :visits, name: "index_visits_on_org_property_pending_scheduled_at", if_exists: true
    remove_index :visits, name: "index_visits_on_org_property_status_scheduled_at", if_exists: true
    remove_index :visits, name: "index_visits_on_org_unit_scheduled_at", if_exists: true

    add_column :visits, :scheduled_starts_at, :datetime unless column_exists?(:visits, :scheduled_starts_at)
    add_column :visits, :scheduled_ends_at, :datetime unless column_exists?(:visits, :scheduled_ends_at)
    add_column :visits, :actual_started_at, :datetime unless column_exists?(:visits, :actual_started_at)
    add_column :visits, :actual_ended_at, :datetime unless column_exists?(:visits, :actual_ended_at)
    add_column :visits, :approved_at, :datetime unless column_exists?(:visits, :approved_at)
    add_column :visits, :concierge_validated_at, :datetime unless column_exists?(:visits, :concierge_validated_at)
    add_column :visits, :rejected_at, :datetime unless column_exists?(:visits, :rejected_at)
    add_column :visits, :rejection_reason, :text unless column_exists?(:visits, :rejection_reason)
    add_column :visits, :authorization_method, :string unless column_exists?(:visits, :authorization_method)

    add_reference :visits, :created_by_person,
                  type: :uuid, null: true, foreign_key: { to_table: :people }, index: true unless column_exists?(:visits, :created_by_person_id)
    add_reference :visits, :responsible_person,
                  type: :uuid, null: true, foreign_key: { to_table: :people }, index: true unless column_exists?(:visits, :responsible_person_id)
    add_reference :visits, :approved_by_person,
                  type: :uuid, null: true, foreign_key: { to_table: :people }, index: true unless column_exists?(:visits, :approved_by_person_id)
    add_reference :visits, :concierge_validated_by_person,
                  type: :uuid, null: true, foreign_key: { to_table: :people }, index: true unless column_exists?(:visits, :concierge_validated_by_person_id)
    add_reference :visits, :rejected_by_person,
                  type: :uuid, null: true, foreign_key: { to_table: :people }, index: true unless column_exists?(:visits, :rejected_by_person_id)

    execute <<~SQL.squish if column_exists?(:visits, :scheduled_at)
      UPDATE visits
      SET scheduled_starts_at = scheduled_at,
          scheduled_ends_at = valid_until,
          actual_started_at = checked_in_at,
          actual_ended_at = checked_out_at,
          approved_at = authorized_at,
          responsible_person_id = host_person_id
    SQL

    change_column_null :visits, :scheduled_starts_at, false if column_exists?(:visits, :scheduled_starts_at)

    remove_reference :visits, :property_section, type: :uuid, foreign_key: true, index: true if column_exists?(:visits, :property_section_id)
    remove_reference :visits, :visitor_person, type: :uuid, foreign_key: { to_table: :people }, index: true if column_exists?(:visits, :visitor_person_id)
    remove_reference :visits, :host_person, type: :uuid, foreign_key: { to_table: :people }, index: true if column_exists?(:visits, :host_person_id)
    remove_reference :visits, :created_by, type: :uuid, foreign_key: { to_table: :users }, index: true if column_exists?(:visits, :created_by_id)
    remove_reference :visits, :authorized_by, type: :uuid, foreign_key: { to_table: :users }, index: true if column_exists?(:visits, :authorized_by_id)
    remove_reference :visits, :checked_in_by, type: :uuid, foreign_key: { to_table: :users }, index: true if column_exists?(:visits, :checked_in_by_id)
    remove_reference :visits, :checked_out_by, type: :uuid, foreign_key: { to_table: :users }, index: true if column_exists?(:visits, :checked_out_by_id)

    remove_column :visits, :visit_type if column_exists?(:visits, :visit_type)
    remove_column :visits, :scheduled_at if column_exists?(:visits, :scheduled_at)
    remove_column :visits, :valid_from if column_exists?(:visits, :valid_from)
    remove_column :visits, :valid_until if column_exists?(:visits, :valid_until)
    remove_column :visits, :checked_in_at if column_exists?(:visits, :checked_in_at)
    remove_column :visits, :checked_out_at if column_exists?(:visits, :checked_out_at)
    remove_column :visits, :authorized_at if column_exists?(:visits, :authorized_at)

    add_check_constraint :visits,
                         "scheduled_ends_at IS NULL OR scheduled_ends_at >= scheduled_starts_at",
                         name: "visits_scheduled_range_valid",
                         validate: true unless check_constraint_exists?(:visits, name: "visits_scheduled_range_valid")
    add_index :visits,
              %i[organization_id residential_property_id status scheduled_starts_at],
              name: "index_visits_on_org_property_status_scheduled_starts",
              if_not_exists: true
    add_index :visits,
              %i[organization_id unit_id scheduled_starts_at],
              name: "index_visits_on_org_unit_scheduled_starts",
              if_not_exists: true
    add_index :visits,
              %i[organization_id residential_property_id scheduled_starts_at],
              name: "index_visits_on_org_property_pending_statuses",
              where: "status IN ('pending', 'concierge_validation_pending', 'resident_notified')",
              if_not_exists: true
  end

  private

  def add_mvp_columns!
    add_reference :visits, :property_section,
                  type: :uuid, null: true, foreign_key: true, index: true unless column_exists?(:visits, :property_section_id)
    add_reference :visits, :visitor_person,
                  type: :uuid, null: true, foreign_key: { to_table: :people }, index: true unless column_exists?(:visits, :visitor_person_id)
    add_reference :visits, :host_person,
                  type: :uuid, null: true, foreign_key: { to_table: :people }, index: true unless column_exists?(:visits, :host_person_id)
    add_reference :visits, :created_by,
                  type: :uuid, null: true, foreign_key: { to_table: :users }, index: true unless column_exists?(:visits, :created_by_id)
    add_reference :visits, :authorized_by,
                  type: :uuid, null: true, foreign_key: { to_table: :users }, index: true unless column_exists?(:visits, :authorized_by_id)
    add_reference :visits, :checked_in_by,
                  type: :uuid, null: true, foreign_key: { to_table: :users }, index: true unless column_exists?(:visits, :checked_in_by_id)
    add_reference :visits, :checked_out_by,
                  type: :uuid, null: true, foreign_key: { to_table: :users }, index: true unless column_exists?(:visits, :checked_out_by_id)

    add_column :visits, :visit_type, :string, null: false, default: "guest" unless column_exists?(:visits, :visit_type)
    add_column :visits, :scheduled_at, :datetime unless column_exists?(:visits, :scheduled_at)
    add_column :visits, :valid_from, :datetime unless column_exists?(:visits, :valid_from)
    add_column :visits, :valid_until, :datetime unless column_exists?(:visits, :valid_until)
    add_column :visits, :checked_in_at, :datetime unless column_exists?(:visits, :checked_in_at)
    add_column :visits, :checked_out_at, :datetime unless column_exists?(:visits, :checked_out_at)
    add_column :visits, :authorized_at, :datetime unless column_exists?(:visits, :authorized_at)
  end

  def legacy_columns_present?
    column_exists?(:visits, :scheduled_starts_at) ||
      column_exists?(:visits, :responsible_person_id) ||
      column_exists?(:visits, :created_by_person_id)
  end

  def backfill_mvp_columns!
    execute <<~SQL.squish
      UPDATE visits v
      SET property_section_id = u.property_section_id,
          residential_property_id = u.residential_property_id
      FROM units u
      WHERE v.unit_id = u.id
    SQL

    execute <<~SQL.squish if column_exists?(:visits, :responsible_person_id)
      UPDATE visits
      SET host_person_id = responsible_person_id
      WHERE host_person_id IS NULL AND responsible_person_id IS NOT NULL
    SQL

    execute <<~SQL.squish
      UPDATE visits v
      SET visitor_person_id = sub.person_id
      FROM (
        SELECT DISTINCT ON (visit_id) visit_id, person_id
        FROM visit_participants
        WHERE person_id IS NOT NULL
        ORDER BY visit_id, created_at ASC
      ) sub
      WHERE v.id = sub.visit_id AND v.visitor_person_id IS NULL
    SQL

    execute <<~SQL.squish
      UPDATE visits
      SET visitor_person_id = host_person_id
      WHERE visitor_person_id IS NULL AND host_person_id IS NOT NULL
    SQL

    if column_exists?(:visits, :created_by_person_id)
      execute <<~SQL.squish
        UPDATE visits v
        SET created_by_id = p.user_id
        FROM people p
        WHERE v.created_by_person_id = p.id AND v.created_by_id IS NULL AND p.user_id IS NOT NULL
      SQL
    end

    if column_exists?(:visits, :approved_by_person_id)
      execute <<~SQL.squish
        UPDATE visits v
        SET authorized_by_id = p.user_id
        FROM people p
        WHERE v.approved_by_person_id = p.id AND v.authorized_by_id IS NULL AND p.user_id IS NOT NULL
      SQL
    end

    if column_exists?(:visits, :concierge_validated_by_person_id)
      execute <<~SQL.squish
        UPDATE visits v
        SET checked_in_by_id = p.user_id
        FROM people p
        WHERE v.concierge_validated_by_person_id = p.id
          AND v.checked_in_by_id IS NULL
          AND p.user_id IS NOT NULL
      SQL
    end

    if column_exists?(:visits, :scheduled_starts_at)
      execute <<~SQL.squish
        UPDATE visits
        SET scheduled_at = scheduled_starts_at,
            valid_from = scheduled_starts_at,
            valid_until = scheduled_ends_at,
            checked_in_at = actual_started_at,
            checked_out_at = actual_ended_at,
            authorized_at = approved_at
        WHERE scheduled_at IS NULL
      SQL
    end

    execute <<~SQL.squish
      UPDATE visits
      SET status = 'pending'
      WHERE status IN ('concierge_validation_pending')
    SQL

    execute <<~SQL.squish
      UPDATE visits
      SET status = 'authorized'
      WHERE status = 'resident_notified'
    SQL

    if column_exists?(:visits, :approved_at)
      execute <<~SQL.squish
        UPDATE visits
        SET status = 'authorized'
        WHERE approved_at IS NOT NULL
          AND checked_in_at IS NULL
          AND status NOT IN ('cancelled', 'checked_in', 'checked_out', 'rejected', 'expired')
      SQL
    end

    execute <<~SQL.squish
      UPDATE visits
      SET status = 'checked_in'
      WHERE checked_in_at IS NOT NULL
        AND checked_out_at IS NULL
        AND status NOT IN ('cancelled', 'checked_out', 'rejected', 'expired')
    SQL

    execute <<~SQL.squish
      UPDATE visits
      SET status = 'checked_out'
      WHERE checked_out_at IS NOT NULL
        AND status NOT IN ('cancelled', 'rejected', 'expired')
    SQL
  end

  def remove_incompatible_visits!
    execute <<~SQL.squish
      DELETE FROM visits
      WHERE visitor_person_id IS NULL
         OR host_person_id IS NULL
         OR scheduled_at IS NULL
    SQL
  end

  def enforce_not_nulls!
    change_column_null :visits, :visitor_person_id, false
    change_column_null :visits, :host_person_id, false
    change_column_null :visits, :scheduled_at, false
    change_column_null :visits, :valid_from, false
  end

  def remove_legacy_visit_columns!
    remove_index :visits, name: "index_visits_on_org_property_pending_statuses", if_exists: true
    remove_index :visits, name: "index_visits_on_org_property_status_scheduled_starts", if_exists: true
    remove_index :visits, name: "index_visits_on_org_unit_scheduled_starts", if_exists: true
    remove_check_constraint :visits, name: "visits_scheduled_range_valid", if_exists: true

    remove_reference :visits, :created_by_person, type: :uuid, foreign_key: { to_table: :people }, index: true if column_exists?(:visits, :created_by_person_id)
    remove_reference :visits, :responsible_person, type: :uuid, foreign_key: { to_table: :people }, index: true if column_exists?(:visits, :responsible_person_id)
    remove_reference :visits, :approved_by_person, type: :uuid, foreign_key: { to_table: :people }, index: true if column_exists?(:visits, :approved_by_person_id)
    remove_reference :visits, :concierge_validated_by_person, type: :uuid, foreign_key: { to_table: :people }, index: true if column_exists?(:visits, :concierge_validated_by_person_id)
    remove_reference :visits, :rejected_by_person, type: :uuid, foreign_key: { to_table: :people }, index: true if column_exists?(:visits, :rejected_by_person_id)

    remove_column :visits, :scheduled_starts_at if column_exists?(:visits, :scheduled_starts_at)
    remove_column :visits, :scheduled_ends_at if column_exists?(:visits, :scheduled_ends_at)
    remove_column :visits, :actual_started_at if column_exists?(:visits, :actual_started_at)
    remove_column :visits, :actual_ended_at if column_exists?(:visits, :actual_ended_at)
    remove_column :visits, :approved_at if column_exists?(:visits, :approved_at)
    remove_column :visits, :concierge_validated_at if column_exists?(:visits, :concierge_validated_at)
    remove_column :visits, :rejected_at if column_exists?(:visits, :rejected_at)
    remove_column :visits, :rejection_reason if column_exists?(:visits, :rejection_reason)
    remove_column :visits, :authorization_method if column_exists?(:visits, :authorization_method)
  end

  def replace_visit_indexes!
    remove_index :visits, name: "index_visits_on_org_property_operational", if_exists: true
    remove_index :visits, name: "index_visits_on_org_property_status_valid_from", if_exists: true
    remove_index :visits, name: "index_visits_on_org_unit_valid_from", if_exists: true
    remove_index :visits, name: "index_visits_on_org_property_section", if_exists: true
    remove_index :visits, name: "index_visits_on_visit_type", if_exists: true

    add_index :visits,
              %i[organization_id residential_property_id status scheduled_at],
              name: "index_visits_on_org_property_status_scheduled_at",
              algorithm: :concurrently,
              if_not_exists: true
    add_index :visits,
              %i[organization_id unit_id scheduled_at],
              name: "index_visits_on_org_unit_scheduled_at",
              algorithm: :concurrently,
              if_not_exists: true
    add_index :visits,
              %i[organization_id residential_property_id scheduled_at],
              name: "index_visits_on_org_property_pending_scheduled_at",
              where: "status = 'pending'",
              algorithm: :concurrently,
              if_not_exists: true
    add_index :visits,
              %i[organization_id residential_property_id status checked_out_at],
              name: "index_visits_on_org_property_operational_statuses",
              where: "status IN ('authorized', 'checked_in', 'checked_out')",
              algorithm: :concurrently,
              if_not_exists: true
  end

  def replace_validity_check_constraint!
    remove_check_constraint :visits, name: "visits_validity_window_coherent", if_exists: true

    return if check_constraint_exists?(:visits, name: "visits_validity_range_valid")

    add_check_constraint :visits,
                         "valid_until IS NULL OR valid_until >= valid_from",
                         name: "visits_validity_range_valid",
                         validate: false
    validate_check_constraint :visits, name: "visits_validity_range_valid"
  end
end
