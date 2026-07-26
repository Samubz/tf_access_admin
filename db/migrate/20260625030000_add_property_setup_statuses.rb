# frozen_string_literal: true

class AddPropertySetupStatuses < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :residential_properties,
                          name: "residential_properties_status_allowed",
                          if_exists: true

    add_check_constraint :residential_properties,
                         "status IN ('draft', 'configured', 'active', 'inactive', 'archived')",
                         name: "residential_properties_status_allowed"
  end

  def down
    remove_check_constraint :residential_properties,
                          name: "residential_properties_status_allowed",
                          if_exists: true

    add_check_constraint :residential_properties,
                         "status IN ('active', 'inactive', 'archived')",
                         name: "residential_properties_status_allowed"
  end
end
