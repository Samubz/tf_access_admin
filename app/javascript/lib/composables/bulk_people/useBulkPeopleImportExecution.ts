import { computed, onUnmounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { toast } from 'vue-sonner'
import { useRailsFetch } from '@/lib/composables/useRailsFetch'
import { admin_people_bulk_import_path } from '@/routes'
import type {
  BulkImportRecord,
  BulkImportImportLog,
  BulkImportImportPhase,
  BulkImportImportProgress,
  BulkImportImportSummary,
  BulkImportPreviewSummary,
  BulkImportStatusResponse,
} from '@/types/bulk_import'

const TERMINAL_STATUSES = new Set(['completed', 'completed_with_errors', 'failed', 'cancelled'])

const POLL_INTERVAL_MS = 1500
const FAST_POLL_INTERVAL_MS = 800
const FAST_POLL_DURATION_MS = 12_000

type BulkImportConfirmResponse = {
  bulk_import: BulkImportRecord
  status: string
}

function bulkImportStatusPath(bulkImportId: string) {
  return `${admin_people_bulk_import_path(bulkImportId)}/status`
}

function bulkImportConfirmPath(bulkImportId: string) {
  return `${admin_people_bulk_import_path(bulkImportId)}/confirm`
}

function bulkImportReportPath(bulkImportId: string) {
  return `${admin_people_bulk_import_path(bulkImportId)}/report`
}

function mapSummary(preview: BulkImportPreviewSummary): BulkImportImportSummary {
  return {
    totalRows: preview.total_rows,
    validRows: preview.valid_rows,
    warningRows: preview.warning_rows,
    errorRows: preview.error_rows,
    duplicateRows: preview.duplicate_rows,
    newUnits: preview.valid_rows,
  }
}

function mapLog(entry: BulkImportStatusResponse['logs'][number]): BulkImportImportLog {
  return {
    rowNumber: entry.row_number,
    status: entry.status,
    message: entry.message,
    createdAt: entry.created_at,
  }
}

function formatLogTime(iso?: string) {
  if (!iso) return ''
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return ''
  return date.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

export function useBulkPeopleImportExecution(options: {
  bulkImportId: () => string | null
  bulkImportStatus: () => string | undefined | null
  previewSummary: () => BulkImportPreviewSummary | null
  onBulkImportUpdated?: (record: BulkImportRecord) => void
}) {
  const { t } = useI18n()
  const { railsFetchJson } = useRailsFetch()

  const phase = ref<BulkImportImportPhase>('ready')
  const importValidRowsOnly = ref(true)
  const progress = ref<BulkImportImportProgress | null>(null)
  const logs = ref<BulkImportImportLog[]>([])
  const isConfirming = ref(false)
  const logsCursor = ref<string | null>(null)
  const pollStartedAt = ref<number | null>(null)

  let pollTimer: ReturnType<typeof setTimeout> | null = null

  const summary = computed(() => {
    const preview = options.previewSummary()
    if (!preview) return null
    return mapSummary(preview)
  })

  const hasPendingIssues = computed(() => {
    const current = summary.value
    if (!current) return false
    return current.errorRows > 0 || current.warningRows > 0 || current.duplicateRows > 0
  })

  const canConfirmImport = computed(() => {
    if (phase.value !== 'ready' || isConfirming.value) return false
    if (options.bulkImportStatus() !== 'validated') return false
    const current = summary.value
    if (!current) return false
    if (current.newUnits === 0 && current.warningRows === 0) return false
    if (current.errorRows > 0 && !importValidRowsOnly.value) return false
    return true
  })

  const isProcessing = computed(() => phase.value === 'processing')
  const isCompleted = computed(() => phase.value === 'completed')
  const isFailed = computed(() => phase.value === 'failed')

  function resetExecutionState() {
    stopPolling()
    phase.value = 'ready'
    progress.value = null
    logs.value = []
    isConfirming.value = false
    logsCursor.value = null
    pollStartedAt.value = null
  }

  function stopPolling() {
    if (pollTimer) {
      clearTimeout(pollTimer)
      pollTimer = null
    }
  }

  function schedulePoll() {
    stopPolling()
    const elapsed = pollStartedAt.value ? Date.now() - pollStartedAt.value : 0
    const interval = elapsed < FAST_POLL_DURATION_MS ? FAST_POLL_INTERVAL_MS : POLL_INTERVAL_MS
    pollTimer = setTimeout(() => {
      void pollStatus()
    }, interval)
  }

  function mergeLogs(incoming: BulkImportImportLog[]) {
    if (incoming.length === 0) return

    const byKey = new Map<string, BulkImportImportLog>()
    for (const entry of [ ...logs.value, ...incoming ]) {
      const key = `${entry.rowNumber}:${entry.createdAt ?? entry.message}`
      byKey.set(key, entry)
    }

    logs.value = Array.from(byKey.values())
      .sort((a, b) => {
        const timeA = a.createdAt ? new Date(a.createdAt).getTime() : 0
        const timeB = b.createdAt ? new Date(b.createdAt).getTime() : 0
        return timeB - timeA
      })
      .slice(0, 30)
  }

  function applyStatusPayload(data: BulkImportStatusResponse) {
    progress.value = {
      total: data.progress.total,
      processed: data.progress.processed,
      created: data.progress.created,
      skipped: data.progress.skipped,
      failed: data.progress.failed,
      percentage: data.progress.percentage,
    }

    mergeLogs(data.logs.map(mapLog))

    const timestamps = data.logs
      .map((log) => log.created_at)
      .filter((value): value is string => Boolean(value))
      .sort()
    const latestTimestamp = timestamps[timestamps.length - 1]

    if (latestTimestamp) {
      logsCursor.value = latestTimestamp ?? logsCursor.value
    }

    if (TERMINAL_STATUSES.has(data.status)) {
      stopPolling()
      phase.value = data.status === 'failed' ? 'failed' : 'completed'
      return
    }

    if (data.status === 'processing' || data.status === 'confirmed') {
      phase.value = 'processing'
      schedulePoll()
    }
  }

  async function pollStatus() {
    const bulkImportId = options.bulkImportId()
    if (!bulkImportId) return

    try {
      const params = new URLSearchParams()
      if (logsCursor.value) {
        params.set('logs_after', logsCursor.value)
      }

      const query = params.toString()
      const url = `${bulkImportStatusPath(bulkImportId)}${query ? `?${query}` : ''}`

      const { res, data } = await railsFetchJson<BulkImportStatusResponse>('GET', url)

      if (!res.ok) return

      applyStatusPayload(data)
    } catch {
      schedulePoll()
    }
  }

  async function confirmImport() {
    const bulkImportId = options.bulkImportId()
    if (!bulkImportId || !canConfirmImport.value) return

    const currentStatus = options.bulkImportStatus()
    if (currentStatus === 'confirmed' || currentStatus === 'processing') {
      resumeIfInProgress(currentStatus)
      return
    }
    if (currentStatus && currentStatus !== 'validated') {
      toast.error(t('admin.people.bulk_import.errors.wizard_locked'))
      return
    }

    isConfirming.value = true
    phase.value = 'processing'
    pollStartedAt.value = Date.now()
    progress.value = {
      total: summary.value?.newUnits ?? 0,
      processed: 0,
      created: 0,
      skipped: 0,
      failed: 0,
      percentage: 0,
    }

    try {
      const { res, data } = await railsFetchJson<BulkImportConfirmResponse>(
        'POST',
        bulkImportConfirmPath(bulkImportId),
        JSON.stringify({ import_valid_rows_only: importValidRowsOnly.value }),
        { headers: { 'Content-Type': 'application/json' } },
      )

      if (!res.ok) {
        phase.value = 'ready'
        toast.error(t('admin.people.bulk_import.import.errors.confirm_failed'))
        return
      }

      if (data.bulk_import) {
        options.onBulkImportUpdated?.(data.bulk_import)
      }

      if (TERMINAL_STATUSES.has(data.status)) {
        applyStatusPayload({
          status: data.status,
          progress: progress.value ?? {
            total: 0,
            processed: 0,
            created: 0,
            skipped: 0,
            failed: 0,
            percentage: 100,
          },
          logs: [],
          summary: {
            total_rows: 0,
            valid_rows: 0,
            warning_rows: 0,
            error_rows: 0,
            duplicate_rows: 0,
            skipped_rows: 0,
            imported_rows: 0,
            failed_rows: 0,
          },
        })
        return
      }

      await pollStatus()
    } catch {
      phase.value = 'ready'
      toast.error(t('admin.people.bulk_import.import.errors.confirm_failed'))
    } finally {
      isConfirming.value = false
    }
  }

  function downloadReport() {
    const bulkImportId = options.bulkImportId()
    if (!bulkImportId) return

    window.location.assign(bulkImportReportPath(bulkImportId))
  }

  watch(
    () => options.previewSummary(),
    (preview) => {
      if (!preview) return
      importValidRowsOnly.value =
        preview.error_rows > 0 || preview.warning_rows > 0 || preview.duplicate_rows > 0
    },
    { immediate: true },
  )

  function resumeIfInProgress(status: string | undefined) {
    if (!status) return

    if (status === 'processing' || status === 'confirmed') {
      phase.value = 'processing'
      pollStartedAt.value = Date.now()
      void pollStatus()
      return
    }

    if (TERMINAL_STATUSES.has(status)) {
      phase.value = status === 'failed' ? 'failed' : 'completed'
      void pollStatus()
    }
  }

  onUnmounted(() => {
    stopPolling()
  })

  return {
    summary,
    phase,
    importValidRowsOnly,
    progress,
    logs,
    isConfirming,
    hasPendingIssues,
    canConfirmImport,
    isProcessing,
    isCompleted,
    isFailed,
    resetExecutionState,
    resumeIfInProgress,
    confirmImport,
    downloadReport,
    formatLogTime,
  }
}
