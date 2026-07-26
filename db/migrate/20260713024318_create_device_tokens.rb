# frozen_string_literal: true

class CreateDeviceTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :device_tokens, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.string :token, null: false
      t.string :platform, null: false
      t.datetime :last_seen_at

      t.timestamps
    end
  end
end
