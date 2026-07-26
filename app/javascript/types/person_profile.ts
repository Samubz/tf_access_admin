import type { Person } from '@/types/person'
import type { TableMeta } from '@/types/table'

export type PersonContextualRole =
  | 'owner'
  | 'resident'
  | 'visitor'
  | 'concierge'
  | 'property_admin'
  | 'cleaning_staff'
  | 'internal_staff'
  | 'system_user'

export type PersonProfileSummary = {
  active_ownerships_count: number
  active_occupancies_count: number
  visits_count: number
  staff_assignments_count: number
}

export type PersonOwnershipRow = {
  id: string
  ownership_percentage: number
  starts_at: string
  ends_at: string | null
  status: string
  validity_state: 'current' | 'finished' | 'pending' | 'inactive'
  residential_property_id: string
  residential_property_name: string | null
  property_section_id: string | null
  property_section_name: string | null
  unit_id: string
  unit_identifier: string
}

export type PersonOccupancyRow = {
  id: string
  occupancy_type: string
  occupancy_type_label: string
  starts_at: string
  ends_at: string | null
  status: string
  status_label: string
  validity_state: 'current' | 'finished' | 'pending' | 'inactive'
  residential_property_id: string
  residential_property_name: string | null
  property_section_id: string | null
  property_section_name: string | null
  unit_id: string
  unit_identifier: string
}

export type PersonChangeHistoryEntry = {
  id: string
  occurred_at: string
  description: string
  actor_name: string
  tone: 'success' | 'warning' | 'neutral'
  source_type: string
  source_id: string
}

export type PersonStaffAssignment = {
  id: string
  residential_property_name: string
  role: string
  status: string
  starts_at: string | null
  ends_at: string | null
}

export type PersonVisitRow = {
  id: string
  occurred_at: string
  residential_property_name: string
  unit_identifier: string
  status: string
}

export type PersonProfilePermissions = {
  view: boolean
  update: boolean
  destroy: boolean
  edit: boolean
}

export type PersonProfileProps = {
  person: Person
  contextual_roles: PersonContextualRole[]
  summary: PersonProfileSummary
  ownerships: PersonOwnershipRow[]
  ownerships_pagination: TableMeta
  occupancies: PersonOccupancyRow[]
  occupancies_pagination: TableMeta
  change_history: PersonChangeHistoryEntry[]
  staff_assignments: PersonStaffAssignment[]
  visits: PersonVisitRow[]
  permissions: PersonProfilePermissions
}
