# frozen_string_literal: true

# Enables accent-insensitive name search for visit form option endpoints
# (improve-admin-visit-form-inputs, design.md Decision 7). No data or table
# changes; safe to disable on rollback.
class EnableUnaccentExtension < ActiveRecord::Migration[8.1]
  def change
    enable_extension "unaccent"
  end
end
