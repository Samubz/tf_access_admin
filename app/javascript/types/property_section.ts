export type PropertySectionUnitTreeNode = {
  id: string
  identifier: string
  display_name: string | null
  unit_type: string
}

export type PropertySectionPermissions = {
  view: boolean
  edit: boolean
  move: boolean
  add_child: boolean
  archive: boolean
}

export type PropertySectionStructurePermissions = {
  view: boolean
  manage: boolean
  create_root: boolean
}

/** Canonical lifecycle values — keep in sync with `SectionStatuses::ALL`. */
export type PropertySectionStatus = 'active' | 'inactive' | 'archived'

export type PropertySectionTreeNode = {
  id: string
  name: string
  code: string | null
  normalized_name?: string
  section_type: string
  position: number | null
  status: PropertySectionStatus
  effective_status: PropertySectionStatus
  parent_id: string | null
  depth: number
  path: string[]
  selected?: boolean
  disabled: boolean
  permissions: PropertySectionPermissions
  children: PropertySectionTreeNode[]
  units: PropertySectionUnitTreeNode[]
}

export type PropertySection = {
  id?: string
  name: string
  code: string | null
  section_type: string
  position: number | null
  status?: PropertySectionStatus
  residential_property_id: string
  residential_property_name?: string | null
  parent_id: string | null
  parent_name?: string | null
  metadata?: Record<string, unknown>
  organization_id?: string
  created_at?: string
  updated_at?: string
}

export type PropertySectionParentOption = {
  id: string
  name: string
  section_type: string
  depth: number
}
