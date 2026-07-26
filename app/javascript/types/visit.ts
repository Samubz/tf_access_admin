export type VisitPersonSummary = {
  id: string
  display_name: string
}

// The unit's current active residents with can_authorize_visits: true,
// computed live (not a per-visit snapshot). Replaces the removed "host"
// concept — see openspec/changes/remove-visit-host-use-unit-authorizers.
export type VisitAuthorizerSummary = {
  id: string
  display_name: string
}

export type VisitUnitSummary = {
  id: string
  identifier: string
  display_name: string | null
}

export type ConciergeVisitPermissions = {
  show: boolean
  check_in: boolean
  check_out: boolean
  restricted_detail: boolean
}

export type ConciergeVisitListItem = {
  id: string
  status: string
  status_label: string
  effective_status?: string
  effective_status_label?: string
  visit_type: string | null
  visit_type_label: string | null
  scheduled_at: string
  valid_from: string
  authorized_at: string | null
  checked_in_at: string | null
  checked_out_at: string | null
  duration_seconds?: number | null
  visitor: VisitPersonSummary | null
  authorizers: VisitAuthorizerSummary[]
  unit: VisitUnitSummary | null
  permissions: ConciergeVisitPermissions
  actions: string[]
  operational_timeline?: VisitTimelineEntry[]
  authorized_by_name?: string | null
  checked_in_by_name?: string | null
  checked_out_by_name?: string | null
  denial_reason?: string | null
  denial_explanation?: string | null
}

export type VisitTimelineEntry = {
  id: string
  event_type: string
  event_type_label: string
  occurred_at: string
  actor_name: string | null
  tone: 'success' | 'neutral' | 'warning'
}

export type ConciergeVisitSummary = ConciergeVisitListItem & {
  valid_until: string | null
}

export type ConciergeVisitTab = 'expected_today' | 'currently_inside'

export type ConciergeVisitCounters = {
  expected_today: number
  currently_inside: number
  authorized: number
  checked_in: number
  recent_checked_out: number
}

export type AssignedPropertySummary = {
  id: string
  name: string
}

export type PropertySummary = {
  id: string
  name: string
}

export type UnitFilterOption = {
  id: string
  identifier: string
  display_name: string | null
  residential_property_id: string
}

export type AdminVisitPermissions = {
  show: boolean
  create: boolean
  update: boolean
  authorize: boolean
  cancel: boolean
  check_in: boolean
  check_out: boolean
  resend_notification: boolean
  full_detail: boolean
  restricted_detail: boolean
  contextual_detail?: boolean
}

export type VisitNotificationStatus = 'pending' | 'delivered' | 'failed' | 'no_recipients'

export type AdminVisitListItem = {
  id: string
  status: string
  status_label: string
  visit_type: string | null
  visit_type_label: string | null
  scheduled_at: string
  valid_from: string
  valid_until: string | null
  authorized_at: string | null
  checked_in_at: string | null
  checked_out_at: string | null
  visitor: VisitPersonSummary | null
  authorizers: VisitAuthorizerSummary[]
  unit: VisitUnitSummary | null
  residential_property: PropertySummary | null
  notification_status: VisitNotificationStatus
  notification_status_label: string
  permissions: AdminVisitPermissions
  actions: string[]
  operational_timeline?: VisitTimelineEntry[]
  checked_in_by_name?: string | null
}

export type AdminVisitScope = 'organization' | 'assigned'

export type VisitPersonDetail = {
  id: string
  display_name: string
  first_name?: string | null
  last_name?: string | null
  person_type?: string
  document_type?: string | null
  document_number?: string | null
  email?: string | null
  phone?: string | null
}

export type VisitActor = {
  id: string
  name: string
  email: string
}

export type VisitHistoryEntry = {
  id: string
  event_type: string
  event_type_label: string
  from_status?: string | null
  from_status_label?: string | null
  to_status?: string | null
  to_status_label?: string | null
  occurred_at: string
  notes?: string | null
  metadata?: Record<string, unknown>
  actor_user_id?: string | null
  actor_name?: string | null
  actor_email?: string | null
}

export type VisitMetadata = {
  vehicle?: {
    plate?: string
    brand_model?: string
    color?: string
  }
  check_in?: Record<string, string>
  check_out?: Record<string, string>
}

export type AdminVisitDetail = AdminVisitListItem & {
  notes?: string | null
  metadata?: VisitMetadata
  visitor_detail?: VisitPersonDetail | null
  unit_detail?: (VisitUnitSummary & {
    residential_property_id?: string
    property_section_id?: string | null
  }) | null
  created_by_actor?: VisitActor | null
  authorized_by_actor?: VisitActor | null
  checked_in_by_actor?: VisitActor | null
  checked_out_by_actor?: VisitActor | null
  history?: VisitHistoryEntry[]
}

export type AdminVisitRestrictedDetail = {
  id: string
  status: string
  status_label: string
  visit_type: string | null
  visit_type_label: string | null
  scheduled_at: string
  valid_from: string
  valid_until: string | null
  authorized_at: string | null
  checked_in_at: string | null
  checked_out_at: string | null
  residential_property_id?: string
  unit_id?: string
  visitor_person_id?: string
  visitor: VisitPersonSummary | null
  authorizers: VisitAuthorizerSummary[]
  unit: VisitUnitSummary | null
  residential_property: PropertySummary | null
  permissions: {
    show: boolean
    check_in: boolean
    check_out: boolean
    restricted_detail: boolean
  }
  actions: string[]
  history?: VisitHistoryEntry[]
}

export type AdminVisitContextualPermissions = {
  show: boolean
  create: boolean
  authorize: boolean
  cancel: boolean
  check_in: boolean
  check_out: boolean
  full_detail: false
  restricted_detail: false
  contextual_detail: true
}

export type AdminVisitContextualDetail = AdminVisitListItem & {
  notes?: string | null
  metadata?: VisitMetadata
  visitor_detail?: Pick<VisitPersonDetail, 'id' | 'display_name' | 'document_number' | 'phone'> | null
  history?: VisitHistoryEntry[]
  contextual_detail: true
  permissions: AdminVisitContextualPermissions
}

export type AdminVisitShowItem = AdminVisitDetail | AdminVisitRestrictedDetail | AdminVisitContextualDetail

export type UnitVisitPermissions = {
  create: boolean
}

export type UnitVisitsPagination = {
  current_page: number
  per_page: number
  total_pages: number
  total_count: number
}

export type VisitContextualCreateUnit = {
  id: string
  identifier: string
  display_name: string | null
  residential_property_id: string
  property_name: string
}

export type VisitContextualCreateContext = {
  unit: VisitContextualCreateUnit
  return_to: {
    type: 'unit'
    residential_property_id: string
    unit_id: string
  } | null
}
