<template>
  <div class="space-y-6">
    <div>
      <h3 class="text-base font-semibold">{{ t('admin.people.bulk_import.preview.title') }}</h3>
      <p class="text-xs text-muted-foreground">{{ t('admin.people.bulk_import.preview.subtitle') }}</p>
    </div>

    <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
      <Card v-for="card in summaryCards" :key="card.key" class="py-3">
        <CardContent class="flex items-center gap-3 px-4">
          <div class="flex size-9 shrink-0 items-center justify-center rounded-lg" :class="card.iconClass">
            <component :is="card.icon" class="size-4" aria-hidden="true" />
          </div>
          <div class="min-w-0">
            <p class="text-xs text-muted-foreground">{{ card.label }}</p>
            <p class="text-xl font-semibold tabular-nums">{{ card.value }}</p>
          </div>
        </CardContent>
      </Card>
    </div>

    <div class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_17rem]">
      <div class="space-y-4">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div class="flex flex-wrap gap-1 rounded-lg border bg-muted/30 p-1">
            <Button
              v-for="filter in previewFilters"
              :key="filter.value"
              type="button"
              size="sm"
              :variant="activeFilter === filter.value ? 'default' : 'ghost'"
              class="h-8"
              :disabled="isLoading"
              @click="activeFilter = filter.value"
            >
              {{ filter.label }}
            </Button>
          </div>

          <div class="relative w-full sm:max-w-xs">
            <Search
              class="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground"
              aria-hidden="true"
            />
            <Input
              v-model="searchQuery"
              type="search"
              class="pl-9"
              :disabled="isLoading"
              :placeholder="t('admin.people.bulk_import.preview.search_placeholder')"
            />
          </div>
        </div>

        <div class="overflow-hidden rounded-lg border">
          <div v-if="isLoading" class="space-y-3 p-4">
            <Skeleton v-for="index in 6" :key="index" class="h-10 w-full" />
          </div>

          <div
            v-else-if="rows.length === 0"
            class="flex min-h-40 items-center justify-center px-6 text-center text-sm text-muted-foreground"
          >
            {{ emptyTableMessage }}
          </div>

          <Table v-else>
            <TableHeader>
              <TableRow>
                <TableHead class="w-16 text-xs">{{ t('admin.people.bulk_import.preview.table.row') }}</TableHead>
                <TableHead class="text-xs">{{ t('admin.people.bulk_import.preview.table.name') }}</TableHead>
                <TableHead class="text-xs">{{ t('admin.people.bulk_import.preview.table.document') }}</TableHead>
                <TableHead class="text-xs">{{ t('admin.people.bulk_import.preview.table.email') }}</TableHead>
                <TableHead class="text-xs">{{ t('admin.people.bulk_import.preview.table.status') }}</TableHead>
                <TableHead class="text-xs">{{ t('admin.people.bulk_import.preview.table.result') }}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              <TableRow v-for="row in rows" :key="row.id" :class="rowTableClass(row)">
                <TableCell class="text-sm tabular-nums text-muted-foreground">{{ row.row_number }}</TableCell>
                <TableCell class="text-sm font-medium">
                  {{ [row.normalized_payload.first_name, row.normalized_payload.last_name].filter(Boolean).join(' ') || '—' }}
                </TableCell>
                <TableCell class="text-sm">{{ row.normalized_payload.document_number ?? '—' }}</TableCell>
                <TableCell class="text-sm">{{ row.normalized_payload.email ?? '—' }}</TableCell>
                <TableCell>
                  <Badge :variant="validationStatusBadgeVariant(row.validation_status)" class="text-xs">
                    {{ formatValidationStatus(row.validation_status) }}
                  </Badge>
                </TableCell>
                <TableCell>
                  <div class="flex items-center gap-2 text-sm">
                    <component :is="resultIcon(row)" class="size-4 shrink-0" :class="resultIconClass(row)" aria-hidden="true" />
                    <span>{{ resultLabel(row) }}</span>
                  </div>
                </TableCell>
              </TableRow>
            </TableBody>
          </Table>
        </div>

        <DataTablePagination
          v-if="pagination.total_count > 0"
          :current-page="pagination.current_page"
          :total-pages="pagination.total_pages"
          :total-items="pagination.total_count"
          :items-per-page="pagination.per_page"
          :items-per-page-options="[...BULK_IMPORT_PREVIEW_PER_PAGE_OPTIONS]"
          :on-page-change="onPageChange"
          :on-items-per-page-change="onItemsPerPageChange"
        />

        <Alert
          v-if="showAttentionAlert && !isLoading"
          class="border-amber-200 bg-amber-50 text-amber-950 dark:border-amber-900/50 dark:bg-amber-950/40 dark:text-amber-100"
        >
          <TriangleAlert class="text-amber-600 dark:text-amber-300" />
          <AlertDescription class="text-amber-900/90 dark:text-amber-100/90">
            {{ t('admin.people.bulk_import.preview.attention_alert') }}
          </AlertDescription>
        </Alert>
      </div>

      <Card class="h-fit py-4">
        <CardContent class="space-y-4 px-4">
          <p class="text-sm font-medium">{{ t('admin.people.bulk_import.preview.summary.title') }}</p>

          <ul class="space-y-3 text-sm">
            <li class="flex items-start gap-2">
              <CircleCheck class="mt-0.5 size-4 shrink-0 text-green-600" aria-hidden="true" />
              <span>{{ t('admin.people.bulk_import.preview.summary.will_create', { count: summary.valid }) }}</span>
            </li>
            <li v-if="summary.duplicates > 0 || summary.skipped > 0" class="flex items-start gap-2">
              <TriangleAlert class="mt-0.5 size-4 shrink-0 text-amber-600" aria-hidden="true" />
              <span>
                {{
                  t('admin.people.bulk_import.preview.summary.will_skip_duplicates', {
                    count: summary.duplicates || summary.skipped,
                  })
                }}
              </span>
            </li>
            <li v-if="summary.errors > 0" class="flex items-start gap-2">
              <CircleX class="mt-0.5 size-4 shrink-0 text-destructive" aria-hidden="true" />
              <span>{{ t('admin.people.bulk_import.preview.summary.needs_correction', { count: summary.errors }) }}</span>
            </li>
          </ul>

          <Alert class="border-sky-200 bg-sky-50 text-sky-950 dark:border-sky-900/50 dark:bg-sky-950/40 dark:text-sky-100">
            <Lightbulb class="text-sky-600 dark:text-sky-300" />
            <AlertTitle>{{ t('admin.people.bulk_import.preview.summary.tip_title') }}</AlertTitle>
            <AlertDescription class="text-sky-900/90 dark:text-sky-100/90">
              {{ t('admin.people.bulk_import.preview.summary.tip_default') }}
            </AlertDescription>
          </Alert>
        </CardContent>
      </Card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, toRef, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { CircleCheck, CircleX, FileSpreadsheet, Lightbulb, Search, TriangleAlert } from 'lucide-vue-next'
import DataTablePagination from '@/components/admin/table/DataTablePagination.vue'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Skeleton } from '@/components/ui/skeleton'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import {
  BULK_IMPORT_PREVIEW_FILTERS,
  BULK_IMPORT_PREVIEW_PER_PAGE_OPTIONS,
  type BulkImportPreviewFilter,
} from '@/lib/constants/bulk_import'
import { useBulkUnitsPreview } from '@/lib/composables/bulk_units/useBulkUnitsPreview'
import { useBulkUnitsPreviewRowsQuery } from '@/lib/composables/bulk_units/useBulkUnitsPreviewRows'
import { useBulkPeoplePreviewRows } from '@/lib/composables/bulk_people/useBulkPeoplePreviewRows'
import { primaryIssue } from '@/lib/utils/bulk_import_preview'
import type { BulkImportRecord, BulkImportRowsResponse } from '@/types/bulk_import'

const props = defineProps<{
  bulkImport: BulkImportRecord
  initialPreview: BulkImportRowsResponse | null
  isValidating: boolean
}>()

const emit = defineEmits<{
  (e: 'can-continue-change', value: boolean): void
}>()

const { t } = useI18n()

const activeFilter = ref<BulkImportPreviewFilter>('all')
const searchQuery = ref('')

const bulkImportId = toRef(() => props.bulkImport.id)

const { rows, summary: previewSummary, pagination, isLoadingRows, fetchRows, applyPreviewResult } =
  useBulkPeoplePreviewRows(() => bulkImportId.value)

const isLoading = computed(() => props.isValidating || isLoadingRows.value)

const { summary, showAttentionAlert, canContinueToImport, hasDownloadableErrors } = useBulkUnitsPreview(
  () => previewSummary.value,
)

const { onPageChange, onItemsPerPageChange } = useBulkUnitsPreviewRowsQuery(
  () => activeFilter.value,
  () => searchQuery.value,
  fetchRows,
)

watch(
  () => props.initialPreview,
  (preview) => {
    if (preview) applyPreviewResult(preview)
  },
  { immediate: true },
)

watch(
  canContinueToImport,
  (value) => emit('can-continue-change', value),
  { immediate: true },
)

defineExpose({ hasDownloadableErrors })

const previewFilters = computed(() =>
  BULK_IMPORT_PREVIEW_FILTERS.map((value) => ({
    value,
    label: t(`admin.people.bulk_import.preview.filters.${value}`),
  })),
)

const summaryCards = computed(() => [
  {
    key: 'total',
    label: t('admin.people.bulk_import.preview.cards.total'),
    value: summary.value.total,
    icon: FileSpreadsheet,
    iconClass: 'bg-muted text-muted-foreground',
  },
  {
    key: 'valid',
    label: t('admin.people.bulk_import.preview.cards.valid'),
    value: summary.value.valid,
    icon: CircleCheck,
    iconClass: 'bg-green-100 text-green-700 dark:bg-green-950 dark:text-green-300',
  },
  {
    key: 'warnings',
    label: t('admin.people.bulk_import.preview.cards.warnings'),
    value: summary.value.warnings + summary.value.duplicates,
    icon: TriangleAlert,
    iconClass: 'bg-amber-100 text-amber-700 dark:bg-amber-950 dark:text-amber-300',
  },
  {
    key: 'errors',
    label: t('admin.people.bulk_import.preview.cards.errors'),
    value: summary.value.errors,
    icon: CircleX,
    iconClass: 'bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-300',
  },
])

const emptyTableMessage = computed(() => {
  if (summary.value.total === 0) return t('admin.people.bulk_import.preview.empty.no_rows')
  return t('admin.people.bulk_import.preview.empty.no_matches')
})

function formatValidationStatus(status: string) {
  const key = `admin.people.bulk_import.preview.validation_statuses.${status}`
  const translated = t(key)
  return translated === key ? status : translated
}

function validationStatusBadgeVariant(status: string) {
  if (status === 'valid') return 'success'
  if (status === 'warning') return 'outline'
  if (status === 'error') return 'destructive'
  return 'secondary'
}

function resultIcon(row: (typeof rows.value)[number]) {
  if (row.validation_status === 'valid') return CircleCheck
  if (row.validation_status === 'error') return CircleX
  return TriangleAlert
}

function resultIconClass(row: (typeof rows.value)[number]) {
  if (row.validation_status === 'valid') return 'text-green-600'
  if (row.validation_status === 'error') return 'text-destructive'
  return 'text-amber-600'
}

function resultLabel(row: (typeof rows.value)[number]) {
  const issue = primaryIssue(row)
  if (issue?.message) return issue.message

  const codeKey = `admin.people.bulk_import.preview.results.${row.validation_status}`
  const translated = t(codeKey)
  return translated === codeKey ? row.validation_status : translated
}

function rowTableClass(row: (typeof rows.value)[number]) {
  if (row.validation_status === 'error') return 'bg-destructive/5'
  if (row.validation_status === 'duplicate' || row.validation_status === 'warning') {
    return 'bg-amber-50/60 dark:bg-amber-950/20'
  }
  return undefined
}
</script>
