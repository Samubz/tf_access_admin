# frozen_string_literal: true

class ProcessPeopleImportJob < ApplicationJob
  queue_as :default

  def perform(bulk_import_id)
    bulk_import = BulkImport.find(bulk_import_id)
    BulkImportServices::ProcessPeopleImport.call(bulk_import:)
  end
end
