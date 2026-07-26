# frozen_string_literal: true

module Authorization
  module Capabilities
    MANAGE_ORGANIZATION = :manage_organization
    MANAGE_USERS = :manage_users
    MANAGE_PROPERTIES = :manage_properties
    MANAGE_PROPERTY = :manage_property
    MANAGE_SECTIONS = :manage_sections
    VIEW_UNITS = :view_units
    MANAGE_UNITS = :manage_units
    VIEW_PEOPLE = :view_people
    MANAGE_PEOPLE = :manage_people
    VIEW_SENSITIVE_PERSON_DATA = :view_sensitive_person_data
    MANAGE_OWNERSHIPS = :manage_ownerships
    MANAGE_OCCUPANCIES = :manage_occupancies
    VIEW_VISITS = :view_visits
    VIEW_AUTHORIZED_VISITS = :view_authorized_visits
    MANAGE_VISITS = :manage_visits
    CREATE_VISITS = :create_visits
    AUTHORIZE_VISITS = :authorize_visits
    REGISTER_VISIT_ENTRY = :register_visit_entry
    REGISTER_VISIT_EXIT = :register_visit_exit
    VIEW_MINIMAL_ACCESS_CONTROL_DATA = :view_minimal_access_control_data
    VIEW_OWN_UNIT_CONTEXT = :view_own_unit_context
    MANAGE_STAFF_ASSIGNMENTS = :manage_staff_assignments
    # Global identity-conflict resolution. Deliberately super-admin-only by
    # default (see ORGANIZATION_ADMIN below); a property/organization manager
    # must NOT resolve global identity conflicts.
    RESOLVE_IDENTITY_CONFLICTS = :resolve_identity_conflicts

    ALL = [
      MANAGE_ORGANIZATION,
      MANAGE_USERS,
      MANAGE_PROPERTIES,
      MANAGE_PROPERTY,
      MANAGE_SECTIONS,
      VIEW_UNITS,
      MANAGE_UNITS,
      VIEW_PEOPLE,
      MANAGE_PEOPLE,
      VIEW_SENSITIVE_PERSON_DATA,
      MANAGE_OWNERSHIPS,
      MANAGE_OCCUPANCIES,
      VIEW_VISITS,
      VIEW_AUTHORIZED_VISITS,
      MANAGE_VISITS,
      CREATE_VISITS,
      AUTHORIZE_VISITS,
      REGISTER_VISIT_ENTRY,
      REGISTER_VISIT_EXIT,
      VIEW_MINIMAL_ACCESS_CONTROL_DATA,
      VIEW_OWN_UNIT_CONTEXT,
      MANAGE_STAFF_ASSIGNMENTS,
      RESOLVE_IDENTITY_CONFLICTS
    ].freeze

    # Organization admins (tenant_admin) get every capability EXCEPT global
    # identity-conflict resolution, which stays super-admin-only and delegable
    # (granted explicitly in +GrantProfile+).
    ORGANIZATION_ADMIN = (ALL - [ RESOLVE_IDENTITY_CONFLICTS ]).freeze

    CONTENT_MANAGER = [
      MANAGE_PROPERTIES,
      MANAGE_SECTIONS,
      VIEW_UNITS,
      MANAGE_UNITS,
      VIEW_PEOPLE,
      MANAGE_PEOPLE,
      VIEW_SENSITIVE_PERSON_DATA,
      MANAGE_OWNERSHIPS,
      MANAGE_OCCUPANCIES,
      VIEW_VISITS
    ].freeze

    PROPERTY_ADMIN = [
      MANAGE_PROPERTY,
      MANAGE_SECTIONS,
      VIEW_UNITS,
      MANAGE_UNITS,
      VIEW_PEOPLE,
      MANAGE_PEOPLE,
      VIEW_SENSITIVE_PERSON_DATA,
      MANAGE_OWNERSHIPS,
      MANAGE_OCCUPANCIES,
      VIEW_VISITS,
      MANAGE_VISITS,
      MANAGE_STAFF_ASSIGNMENTS
    ].freeze

    CONCIERGE = [
      VIEW_VISITS,
      VIEW_AUTHORIZED_VISITS,
      REGISTER_VISIT_ENTRY,
      REGISTER_VISIT_EXIT,
      VIEW_MINIMAL_ACCESS_CONTROL_DATA
    ].freeze

    CLEANING_STAFF = [].freeze
    INTERNAL_STAFF = [].freeze

    OWNER = [
      CREATE_VISITS,
      AUTHORIZE_VISITS,
      VIEW_OWN_UNIT_CONTEXT
    ].freeze

    RESIDENT = [
      CREATE_VISITS,
      VIEW_OWN_UNIT_CONTEXT
    ].freeze

    RESIDENT_AUTHORIZE_VISITS = AUTHORIZE_VISITS

    ROLE_CAPABILITY_MAP = {
      property_admin: PROPERTY_ADMIN,
      concierge: CONCIERGE,
      cleaning_staff: CLEANING_STAFF,
      internal_staff: INTERNAL_STAFF,
      owner: OWNER,
      resident: RESIDENT
    }.freeze

    module_function

    def known?(capability)
      ALL.include?(normalize(capability))
    end

    def normalize(capability)
      capability.to_sym
    end
  end
end
