# frozen_string_literal: true

class AddNotificationStatusToVisits < ActiveRecord::Migration[8.1]
  def change
    add_column :visits, :notification_status, :string, null: false, default: "pending"
  end
end
