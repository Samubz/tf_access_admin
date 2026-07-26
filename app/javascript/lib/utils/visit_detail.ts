import type { TimelineEntry } from '@/components/admin/shared/Timeline.vue'
import type { AdminVisitDetail, AdminVisitContextualDetail, AdminVisitShowItem, VisitHistoryEntry } from '@/types/visit'

export function historyEventTone(eventType: string): TimelineEntry['tone'] {
  switch (eventType) {
    case 'authorized':
    case 'checked_in':
    case 'checked_out':
      return 'success'
    case 'cancelled':
      return 'warning'
    default:
      return 'neutral'
  }
}

export function historyToTimelineEntries(
  history: VisitHistoryEntry[] | undefined,
): TimelineEntry[] {
  if (!history?.length) return []

  return history.map((entry) => ({
    id: entry.id,
    occurred_at: entry.occurred_at,
    description: entry.event_type_label,
    actor_name: entry.actor_name ?? '—',
    tone: historyEventTone(entry.event_type),
  }))
}

export function isFullVisitDetail(visit: AdminVisitShowItem): visit is AdminVisitDetail {
  return 'full_detail' in visit.permissions && visit.permissions.full_detail === true
}

export function isContextualVisitDetail(visit: AdminVisitShowItem): visit is AdminVisitContextualDetail {
  return 'contextual_detail' in visit.permissions && visit.permissions.contextual_detail === true
}
