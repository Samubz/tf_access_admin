/**
 * Canonical capability keys. Each key corresponds to a constant in
 * Authorization::Capabilities on the backend. Never used for authorization
 * decisions — only for conditional UI rendering (show/hide nav items,
 * action buttons, etc.). Authorization always happens server-side via Pundit.
 */
export type CapabilityKey =
  | 'manage_organization'
  | 'manage_users'
  | 'manage_properties'
  | 'manage_property'
  | 'manage_sections'
  | 'view_units'
  | 'manage_units'
  | 'view_people'
  | 'manage_people'
  | 'view_sensitive_person_data'
  | 'manage_ownerships'
  | 'manage_occupancies'
  | 'view_visits'
  | 'view_authorized_visits'
  | 'manage_visits'
  | 'create_visits'
  | 'authorize_visits'
  | 'register_visit_entry'
  | 'register_visit_exit'
  | 'view_minimal_access_control_data'
  | 'view_own_unit_context'
  | 'manage_staff_assignments'

/**
 * Flat map of every capability key to a boolean indicating whether the
 * current user holds that capability in the current organization context.
 * Served via the `capabilities` Inertia shared prop from AdminController.
 *
 * A value of `true` means the user has the capability org-wide OR in at
 * least one accessible property. Use this only for conditional rendering —
 * never for access control.
 */
export type OperationalCapabilities = Record<CapabilityKey, boolean>

/**
 * Shape for a managed property entry in OperationalUserSummary.
 */
export type ManagedProperty = {
  id: string
  name: string
  role: string
}

/**
 * Shape for a staff assignment summary entry in OperationalUserSummary.
 */
export type StaffAssignmentSummary = {
  residential_property_name: string
  role: string
  status: string
}

/**
 * Read-model for a future user management index row.
 * Mirrors Admin::OperationalUserSummary on the backend.
 *
 * Populated from User, linked Person, organizational role, active
 * StaffAssignments, and effective capability keys. Implemented in
 * section 8 of the operational-roles-and-permissions OpenSpec.
 */
export type OperationalUserSummary = {
  user_id: string
  email: string
  name: string
  person_id: string | null
  organization_role: string
  managed_properties: ManagedProperty[]
  staff_assignments_summary: StaffAssignmentSummary[]
  account_status: string
  capability_keys: CapabilityKey[]
}
