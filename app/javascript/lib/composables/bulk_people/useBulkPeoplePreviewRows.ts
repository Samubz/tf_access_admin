import { ref } from 'vue'
import type { BulkImportPreviewFilter } from '@/lib/constants/bulk_import'
import { BULK_IMPORT_PREVIEW_PER_PAGE } from '@/lib/constants/bulk_import'
import type {
  BulkImportPreviewPagination,
  BulkImportPreviewSummary,
  BulkImportRowRecord,
  BulkImportRowsResponse,
} from '@/types/bulk_import'
import { useRailsFetch } from '@/lib/composables/useRailsFetch'
import { admin_people_bulk_import_path } from '@/routes'

type FetchRowsParams = {
  page?: number
  perPage?: number
  filter?: BulkImportPreviewFilter
  search?: string
}

type BulkImportRowsErrorResponse = {
  errors?: Record<string, string[]>
}

function bulkImportRowsPath(bulkImportId: string) {
  return `${admin_people_bulk_import_path(bulkImportId)}/rows`
}

function buildRowsQuery(params: FetchRowsParams) {
  const query = new URLSearchParams()

  if (params.page) query.set('page', String(params.page))
  if (params.perPage) query.set('per_page', String(params.perPage))
  if (params.filter && params.filter !== 'all') query.set('filter', params.filter)
  if (params.search?.trim()) query.set('search', params.search.trim())

  const serialized = query.toString()
  return serialized ? `?${serialized}` : ''
}

export function useBulkPeoplePreviewRows(bulkImportId: () => string | null) {
  const { railsFetchJson } = useRailsFetch()

  const rows = ref<BulkImportRowRecord[]>([])
  const summary = ref<BulkImportPreviewSummary | null>(null)
  const pagination = ref<BulkImportPreviewPagination>({
    current_page: 1,
    per_page: BULK_IMPORT_PREVIEW_PER_PAGE,
    total_pages: 0,
    total_count: 0,
  })
  const isLoadingRows = ref(false)
  const fetchError = ref<string | null>(null)

  async function fetchRows(params: FetchRowsParams = {}) {
    const importId = bulkImportId()
    if (!importId) return false

    isLoadingRows.value = true
    fetchError.value = null

    try {
      const query = buildRowsQuery({
        page: params.page ?? pagination.value.current_page,
        perPage: params.perPage ?? pagination.value.per_page,
        filter: params.filter,
        search: params.search,
      })

      const { res, data } = await railsFetchJson<BulkImportRowsResponse & BulkImportRowsErrorResponse>(
        'GET',
        `${bulkImportRowsPath(importId)}${query}`,
      )

      if (!res.ok) {
        fetchError.value = data.errors?.base?.[0] ?? data.errors?.file?.[0] ?? 'Failed to load preview rows'
        return false
      }

      rows.value = data.rows
      pagination.value = data.pagination
      summary.value = data.summary
      return true
    } catch {
      fetchError.value = 'Failed to load preview rows'
      return false
    } finally {
      isLoadingRows.value = false
    }
  }

  function applyPreviewResult(result: BulkImportRowsResponse) {
    rows.value = result.rows
    pagination.value = result.pagination
    summary.value = result.summary
  }

  function resetPreviewRows() {
    rows.value = []
    summary.value = null
    pagination.value = {
      current_page: 1,
      per_page: BULK_IMPORT_PREVIEW_PER_PAGE,
      total_pages: 0,
      total_count: 0,
    }
    fetchError.value = null
    isLoadingRows.value = false
  }

  return {
    rows,
    summary,
    pagination,
    isLoadingRows,
    fetchError,
    fetchRows,
    applyPreviewResult,
    resetPreviewRows,
  }
}
