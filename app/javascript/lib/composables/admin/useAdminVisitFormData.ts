import { ref } from 'vue'
import { useRailsFetch } from '@/lib/composables/useRailsFetch'
import type { VisitInitialStatusPreview } from '@/lib/schemas/visit_create'

export function useAdminVisitFormData() {
  const { railsFetchJson } = useRailsFetch()

  const initialStatusPreview = ref<VisitInitialStatusPreview | null>(null)
  const statusLoading = ref(false)

  async function fetchInitialStatusPreview(unitId: string) {
    if (!unitId) {
      initialStatusPreview.value = null
      return
    }

    statusLoading.value = true

    try {
      const { res, data } = await railsFetchJson<VisitInitialStatusPreview>(
        'GET',
        `/admin/visits/initial_status_preview?unit_id=${encodeURIComponent(unitId)}`,
      )
      initialStatusPreview.value = res.ok ? data : null
    } finally {
      statusLoading.value = false
    }
  }

  return {
    initialStatusPreview,
    statusLoading,
    fetchInitialStatusPreview,
  }
}
