# frozen_string_literal: true

class AddOnboardingClassificationToBulkImportRows < ActiveRecord::Migration[8.1]
  def change
    add_column :bulk_import_rows, :onboarding_classification, :string
  end
end
