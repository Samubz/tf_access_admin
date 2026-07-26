import { ref } from 'vue'
import { router } from '@inertiajs/vue3'
import type { ConciergeVisitTab } from '@/types/visit'

type ListQuery = {
  search: string
  page: number
  itemsPerPage: number
  tab: ConciergeVisitTab
  propertyId?: string | null
}

export function useConciergeVisitsList(initialTab: ConciergeVisitTab = 'expected_today') {
  const activeTab = ref<ConciergeVisitTab>(initialTab)

  function buildQueryParams({ search, page, itemsPerPage, tab, propertyId }: ListQuery) {
    const params: Record<string, string | number | Record<string, string>> = {
      page,
      per_page: itemsPerPage,
      tab,
    }

    const trimmedSearch = search.trim()
    if (trimmedSearch) {
      params.q = { query: trimmedSearch }
      params.include_denied = '1'
    }

    if (propertyId) {
      params.property_id = propertyId
    }

    return params
  }

  function fetchVisits(query: ListQuery) {
    activeTab.value = query.tab

    router.get('/concierge/visits', buildQueryParams(query), {
      preserveState: true,
      preserveScroll: true,
      only: ['visits', 'pagination', 'counters', 'tab', 'query', 'assigned_property'],
    })
  }

  function refreshList() {
    router.reload({
      only: ['visits', 'pagination', 'counters', 'tab', 'query', 'assigned_property'],
    })
  }

  return {
    activeTab,
    fetchVisits,
    refreshList,
  }
}
