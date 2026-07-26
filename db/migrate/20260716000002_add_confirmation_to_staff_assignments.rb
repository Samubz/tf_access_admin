# frozen_string_literal: true

class AddConfirmationToStaffAssignments < ActiveRecord::Migration[8.1]
  def up
    # Default "confirmed" preserves current behavior: existing rows and any
    # non-onboarding creation stay confirmed. The onboarding flow explicitly
    # creates operational roles as "pending" (spec property-onboarding §
    # "Operational roles are confirmable"). Enforcement in Authorization::Resolver
    # is deferred (tasks §16.2/§17).
    add_column :staff_assignments, :confirmation_state, :string, null: false, default: "confirmed"
    add_column :staff_assignments, :confirmed_at, :datetime

    # Tidy backfill: stamp existing confirmed rows with a confirmation time.
    execute <<~SQL.squish
      UPDATE staff_assignments
      SET confirmed_at = updated_at
      WHERE confirmation_state = 'confirmed' AND confirmed_at IS NULL
    SQL

    add_index :staff_assignments, :confirmation_state
  end

  def down
    remove_index :staff_assignments, :confirmation_state
    remove_column :staff_assignments, :confirmed_at
    remove_column :staff_assignments, :confirmation_state
  end
end
