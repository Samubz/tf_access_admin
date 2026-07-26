# frozen_string_literal: true

class EvolveVisitStatusHistoriesMvpContract < ActiveRecord::Migration[8.1]
  def change
    change_column_null :visit_status_histories, :event_type, false
    change_column_null :visit_status_histories, :occurred_at, false

    add_index :visit_status_histories,
              %i[organization_id event_type],
              name: "index_visit_status_histories_on_org_event_type"
  end
end
