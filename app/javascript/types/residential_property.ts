export type ResidentialPropertyPermissions = {
  update: boolean
  activate: boolean
  deactivate: boolean
  archive: boolean
}

export type ResidentialProperty = {
  id?: string
  name: string
  code: string | null
  property_type: string
  address_line: string | null
  city: string | null
  region: string | null
  country: string
  timezone: string
  status: string
  metadata?: Record<string, unknown>
  organization_id?: string
  created_at?: string
  updated_at?: string
  permissions?: ResidentialPropertyPermissions
  actions?: string[]
}
