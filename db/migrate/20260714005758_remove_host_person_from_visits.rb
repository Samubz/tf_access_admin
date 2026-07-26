# frozen_string_literal: true

class RemoveHostPersonFromVisits < ActiveRecord::Migration[8.1]
  def change
    remove_reference :visits, :host_person, foreign_key: { to_table: :people }, index: true
  end
end
