export type OperationalRoleKey = 'property_admin' | 'concierge' | 'cleaning_staff' | 'internal_staff'
export type OrgRoleKey = 'tenant_admin' | 'content_manager'
export type AnyRoleKey = OperationalRoleKey | OrgRoleKey
export type RoleScope = 'property' | 'organization' | 'unit' | 'none'

export interface OperationalRoleDefinition {
  key: AnyRoleKey
  name: string
  description: string
  scope: RoleScope
  scope_label: string
  users_count?: number
  capabilities?: string[]
  assignable?: boolean
}

export interface AssignablePerson {
  id: string
  display_name: string
  user_email: string | null
  has_user: boolean
}

export interface AssignmentRow {
  id: string
  person_id: string
  person_name: string | null
  user_email: string | null
  user_name: string | null
  role: string | null
  role_key: OperationalRoleKey | null
  staff_type: string
  residential_property_id: string
  property_name: string | null
  scope_label: string
  status: string
  starts_at: string | null
  ends_at: string | null
}

export interface CapabilityEntry {
  key: string
  label: string
  description?: string
  granted?: boolean
  access?: 'allowed' | 'restricted' | 'denied'
  roles?: Record<string, boolean>
}

export interface CapabilityModuleGroup {
  module: string
  module_key: string
  capabilities: CapabilityEntry[]
}

export interface RoleSummary {
  defined_roles_count: number
  total_capabilities_count: number
  total_assignments_count: number
  assigned_users_count: number
  properties_with_assignments?: number
}

export interface MatrixRoleColumn {
  key: string
  label: string
}

export interface AccessibleProperty {
  id: string
  name: string
}

export interface RoleUser {
  assignment_id: string | null
  person_id: string
  person_name: string | null
  user_email: string | null
  property_id: string | null
  property_name: string | null
  scope_label: string
  status: string
  starts_at: string | null
  ends_at: string | null
}

export interface AvailableRoleOption {
  key: OperationalRoleKey
  name: string
  scope: RoleScope
  scope_label: string
}
