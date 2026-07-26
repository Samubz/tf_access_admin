import { ref } from 'vue'
import { useRailsFetch } from '@/lib/composables/useRailsFetch'
import { trigger_invitations_admin_people_bulk_import_path } from '@/routes'
import type { BulkImportTriggerInvitationsResult } from '@/types/bulk_import'

export function useTriggerRowInvitations(bulkImportId: () => string | null) {
  const { railsFetchJson } = useRailsFetch()
  const isTriggering = ref(false)

  async function triggerInvitations(rowIds?: string[]) {
    const importId = bulkImportId()
    if (!importId) return null

    isTriggering.value = true
    try {
      const { res, data } = await railsFetchJson<BulkImportTriggerInvitationsResult>(
        'POST',
        trigger_invitations_admin_people_bulk_import_path(importId),
        JSON.stringify({ row_ids: rowIds }),
        { headers: { 'Content-Type': 'application/json' } },
      )
      return res.ok ? data : null
    } finally {
      isTriggering.value = false
    }
  }

  return { isTriggering, triggerInvitations }
}
