import { ref } from 'vue'
import { router } from '@inertiajs/vue3'
import { admin_visits_path } from '@/routes'
import type { AdminVisitScope } from '@/types/visit'

type ListQuery = {
  search: string
  page: number
  itemsPerPage: number
  scope: AdminVisitScope
  propertyId: string
  unitId: string
  status: string
  dateFrom: string
  dateTo: string
}

export function useAdminVisitsList(initialScope: AdminVisitScope = 'organization') {
  const activeScope = ref<AdminVisitScope>(initialScope)
  const propertyFilter = ref('')
  const unitFilter = ref('')
  const statusFilter = ref('')
  const dateFromFilter = ref('')
  const dateToFilter = ref('')

  function buildQueryParams(query: ListQuery) {
    const q: Record<string, string> = {}

    if (query.search.trim()) {
      q.visitor_person_display_name_or_unit_identifier_cont = query.search.trim()
    }
    if (query.propertyId) q.residential_property_id_eq = query.propertyId
    if (query.unitId) q.unit_id_eq = query.unitId
    if (query.status) q.status_eq = query.status
    if (query.dateFrom) q.scheduled_at_gteq = query.dateFrom
    if (query.dateTo) q.scheduled_at_lteq = `${query.dateTo} 23:59:59`

    return {
      page: query.page,
      per_page: query.itemsPerPage,
      scope: query.scope,
      q,
    }
  }

  function fetchVisits(query: ListQuery) {
    activeScope.value = query.scope
    propertyFilter.value = query.propertyId
    unitFilter.value = query.unitId
    statusFilter.value = query.status
    dateFromFilter.value = query.dateFrom
    dateToFilter.value = query.dateTo

    router.get(admin_visits_path(), buildQueryParams(query), {
      preserveState: true,
      preserveScroll: true,
      only: ['visits', 'pagination', 'filters', 'scope', 'units'],
    })
  }

  function refreshList() {
    router.reload({
      only: ['visits', 'pagination', 'filters', 'scope', 'units'],
    })
  }

  return {
    activeScope,
    propertyFilter,
    unitFilter,
    statusFilter,
    dateFromFilter,
    dateToFilter,
    fetchVisits,
    refreshList,
  }
}
