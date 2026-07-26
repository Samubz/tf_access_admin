# frozen_string_literal: true

module OperationalRoles
  # Builds localized props for operational roles admin UI.
  module Presentation
    CAPABILITY_MODULES = [
      { module_key: :general, capabilities: [
        Authorization::Capabilities::MANAGE_ORGANIZATION,
        Authorization::Capabilities::MANAGE_USERS
      ] },
      { module_key: :properties, capabilities: [
        Authorization::Capabilities::MANAGE_PROPERTIES,
        Authorization::Capabilities::MANAGE_PROPERTY,
        Authorization::Capabilities::MANAGE_SECTIONS
      ] },
      { module_key: :units, capabilities: [
        Authorization::Capabilities::VIEW_UNITS,
        Authorization::Capabilities::MANAGE_UNITS
      ] },
      { module_key: :people, capabilities: [
        Authorization::Capabilities::VIEW_PEOPLE,
        Authorization::Capabilities::MANAGE_PEOPLE,
        Authorization::Capabilities::VIEW_SENSITIVE_PERSON_DATA
      ] },
      { module_key: :ownerships, capabilities: [ Authorization::Capabilities::MANAGE_OWNERSHIPS ] },
      { module_key: :occupancies, capabilities: [ Authorization::Capabilities::MANAGE_OCCUPANCIES ] },
      { module_key: :visits, capabilities: [
        Authorization::Capabilities::VIEW_VISITS,
        Authorization::Capabilities::VIEW_AUTHORIZED_VISITS,
        Authorization::Capabilities::MANAGE_VISITS,
        Authorization::Capabilities::CREATE_VISITS,
        Authorization::Capabilities::AUTHORIZE_VISITS,
        Authorization::Capabilities::REGISTER_VISIT_ENTRY,
        Authorization::Capabilities::REGISTER_VISIT_EXIT,
        Authorization::Capabilities::VIEW_MINIMAL_ACCESS_CONTROL_DATA
      ] },
      { module_key: :staff, capabilities: [ Authorization::Capabilities::MANAGE_STAFF_ASSIGNMENTS ] },
      { module_key: :own_unit, capabilities: [ Authorization::Capabilities::VIEW_OWN_UNIT_CONTEXT ] }
    ].freeze

    module_function

    def role_json(role, users_count:)
      {
        key: role[:key],
        name: role_name(role[:key]),
        description: role_description(role[:key]),
        scope: role[:scope],
        scope_label: scope_label(role[:scope]),
        users_count: users_count,
        assignable: role[:staff_types].present?
      }
    end

    def capability_matrix(roles)
      CAPABILITY_MODULES.map do |group|
        {
          module: I18n.t("operational_roles.capability_modules.#{group[:module_key]}"),
          module_key: group[:module_key].to_s,
          capabilities: group[:capabilities].map do |cap|
            {
              key: cap.to_s,
              label: capability_label(cap),
              description: capability_description(cap),
              roles: roles.each_with_object({}) { |role, hash| hash[role[:key]] = role[:capabilities].include?(cap) }
            }
          end
        }
      end
    end

    def capability_groups_for_role(role)
      CAPABILITY_MODULES.filter_map do |group|
        caps = group[:capabilities].map do |cap|
          granted = role[:capabilities].include?(cap)
          {
            key: cap.to_s,
            label: capability_label(cap),
            description: capability_description(cap),
            granted: granted,
            access: granted ? "allowed" : "denied"
          }
        end

        { module: I18n.t("operational_roles.capability_modules.#{group[:module_key]}"), module_key: group[:module_key].to_s, capabilities: caps }
      end
    end

    def role_name(key)
      I18n.t("operational_roles.role_definitions.#{key}.name", default: key.to_s.humanize)
    end

    def role_description(key)
      I18n.t("operational_roles.role_definitions.#{key}.description", default: "")
    end

    def scope_label(scope, property_name: nil)
      return I18n.t("operational_roles.scopes.property_named", name: property_name) if property_name.present?

      I18n.t("operational_roles.scopes.#{scope}", default: scope.to_s.humanize)
    end

    def capability_label(cap)
      I18n.t("operational_roles.capability_labels.#{cap}", default: cap.to_s.humanize)
    end

    def capability_description(cap)
      I18n.t("operational_roles.capability_descriptions.#{cap}", default: "")
    end

    def matrix_role_columns
      RoleDefinitions.all_for_matrix.map { |role| { key: role[:key], label: role_name(role[:key]) } }
    end
  end
end
