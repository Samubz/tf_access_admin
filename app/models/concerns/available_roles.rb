module AvailableRoles
  SUPER_ADMIN = "super_admin".freeze
  TENANT_ADMIN = "tenant_admin".freeze
  MANAGER = "manager".freeze
  CONTENT_MANAGER = "content_manager".freeze
  CLIENT = "client".freeze
  SELLER = "seller".freeze
  VISITOR = "visitor".freeze

  # Orden de prioridad: el primero es el más importante (rol principal para User#role).
  TENANT_ROLE_PRIORITY = [
    TENANT_ADMIN,
    MANAGER,
    CONTENT_MANAGER,
    VISITOR
  ].freeze
  ROLE_PRIORITY = ([ SUPER_ADMIN ] + TENANT_ROLE_PRIORITY + [ CLIENT ]).freeze

  GLOBAL = [
    SUPER_ADMIN,
    CLIENT
  ].freeze

  TENANT = [
    TENANT_ADMIN,
    MANAGER,
    CONTENT_MANAGER,
    SELLER,
    VISITOR
  ].freeze

  # RESOURCE = [
  #   CONTENT_MANAGER
  # ].freeze

  ALL = (GLOBAL + TENANT).freeze

  # Índice de prioridad para un nombre de rol (menor = más importante).
  # Roles no definidos se consideran de menor prioridad (Float::INFINITY).
  # scope: :tenant o :global
  def self.priority_index(role_name, scope = :tenant)
    idx = scope == :tenant ? TENANT_ROLE_PRIORITY.index(role_name) : ROLE_PRIORITY.index(role_name)
    idx.nil? ? Float::INFINITY : idx
  end
end
