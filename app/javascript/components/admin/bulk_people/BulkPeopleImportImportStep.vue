<template>
  <div class="space-y-6">
    <div class="rounded-lg border border-green-200 bg-green-50/80 p-4 dark:border-green-900 dark:bg-green-950/30">
      <div class="flex items-start gap-3">
        <CheckCircle2 class="mt-0.5 size-5 shrink-0 text-green-600" aria-hidden="true" />
        <div class="min-w-0 flex-1 space-y-4">
          <div>
            <h3 class="text-base font-semibold text-green-900 dark:text-green-100">
              {{ t('admin.people.bulk_import.import.ready.title') }}
            </h3>
            <p class="text-sm text-green-800/90 dark:text-green-200/80">
              {{ t('admin.people.bulk_import.import.ready.description') }}
            </p>
          </div>

          <div class="grid gap-3 sm:grid-cols-3">
            <Card
              v-for="card in summaryStatCards"
              :key="card.key"
              class="border-green-100 bg-white/70 py-3 dark:border-green-900 dark:bg-background/60"
            >
              <CardContent class="flex items-center gap-3 px-4">
                <component :is="card.icon" class="size-5 shrink-0" :class="card.iconClass" />
                <div>
                  <p class="text-xs text-muted-foreground">{{ card.label }}</p>
                  <p class="text-lg font-semibold tabular-nums">{{ card.value }}</p>
                </div>
              </CardContent>
            </Card>
          </div>

          <div
            v-if="summary && summary.errorRows > 0"
            class="flex items-start gap-2 rounded-md border border-amber-200 bg-amber-50/80 px-3 py-2 text-sm text-amber-900 dark:border-amber-900 dark:bg-amber-950/40 dark:text-amber-100"
          >
            <AlertTriangle class="size-4 shrink-0" aria-hidden="true" />
            <span>{{ t('admin.people.bulk_import.import.ready.errors_pending') }}</span>
          </div>

          <label
            v-if="hasPendingIssues"
            class="flex cursor-pointer items-start gap-3 rounded-md border border-green-200/80 bg-white/60 px-3 py-3 dark:border-green-900 dark:bg-background/40"
          >
            <Checkbox
              :model-value="importValidRowsOnly"
              class="mt-0.5"
              :disabled="isProcessing || isCompleted"
              @update:model-value="emit('update:importValidRowsOnly', Boolean($event))"
            />
            <span class="text-sm leading-snug">{{ t('admin.people.bulk_import.import.ready.valid_rows_only') }}</span>
          </label>
        </div>
      </div>
    </div>

    <Card v-if="isCompleted" class="gap-0 overflow-hidden py-0">
      <CardHeader class="flex flex-row items-start justify-between gap-3 border-b px-4 py-3">
        <div>
          <CardTitle class="text-sm font-semibold">{{ t('admin.people.bulk_import.import.row_states.title') }}</CardTitle>
          <p class="text-xs text-muted-foreground">{{ t('admin.people.bulk_import.import.row_states.subtitle') }}</p>
        </div>
        <ListItem
          v-if="hasPendingTriggerableRows"
          as="confirm"
          :onClick="triggerAll"
          :confirmTitle="t('admin.people.bulk_import.import.row_states.actions.confirm_all_title')"
          :confirmDescription="t('admin.people.bulk_import.import.row_states.actions.confirm_all_description')"
        >
          <Button type="button" size="sm" variant="outline" :disabled="isTriggering">
            <Send class="size-4" />
            {{ t('admin.people.bulk_import.import.row_states.actions.invite_all') }}
          </Button>
        </ListItem>
      </CardHeader>
      <CardContent class="space-y-3 px-4 py-4">
        <div v-if="isLoadingRows" class="space-y-2">
          <Skeleton v-for="index in 4" :key="index" class="h-9 w-full" />
        </div>
        <div v-else-if="rowStates.length === 0" class="py-6 text-center text-sm text-muted-foreground">
          {{ t('admin.people.bulk_import.import.row_states.empty') }}
        </div>
        <template v-else>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead class="w-16 text-xs">{{ t('admin.people.bulk_import.preview.table.row') }}</TableHead>
                <TableHead class="text-xs">{{ t('admin.people.bulk_import.preview.table.name') }}</TableHead>
                <TableHead class="text-xs">{{ t('admin.people.bulk_import.import.row_states.classification') }}</TableHead>
                <TableHead class="w-32 text-right text-xs">{{ t('common.table.actions') }}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              <TableRow v-for="row in rowStates" :key="row.id">
                <TableCell class="text-sm tabular-nums text-muted-foreground">{{ row.row_number }}</TableCell>
                <TableCell class="text-sm font-medium">
                  {{ [row.normalized_payload.first_name, row.normalized_payload.last_name].filter(Boolean).join(' ') || '—' }}
                </TableCell>
                <TableCell>
                  <Badge :variant="classificationBadgeVariant(row.onboarding_classification)" class="text-xs">
                    {{ formatClassification(row.onboarding_classification) }}
                  </Badge>
                </TableCell>
                <TableCell class="text-right">
                  <span v-if="isTriggered(row)" class="text-xs text-muted-foreground">
                    {{ t('admin.people.bulk_import.import.row_states.triggered_label') }}
                  </span>
                  <ListItem
                    v-else-if="isTriggerable(row)"
                    as="confirm"
                    :onClick="() => triggerOne(row)"
                    :confirmTitle="t('admin.people.bulk_import.import.row_states.actions.confirm_one_title')"
                    :confirmDescription="t('admin.people.bulk_import.import.row_states.actions.confirm_one_description')"
                  >
                    <Button type="button" size="sm" variant="ghost" :disabled="isTriggering">
                      {{
                        row.onboarding_classification === 'requires_incorporation'
                          ? t('admin.people.bulk_import.import.row_states.actions.incorporate')
                          : t('admin.people.bulk_import.import.row_states.actions.invite')
                      }}
                    </Button>
                  </ListItem>
                </TableCell>
              </TableRow>
            </TableBody>
          </Table>

          <DataTablePagination
            v-if="pagination.total_count > 0"
            :current-page="pagination.current_page"
            :total-pages="pagination.total_pages"
            :total-items="pagination.total_count"
            :items-per-page="pagination.per_page"
            :items-per-page-options="[...BULK_IMPORT_PREVIEW_PER_PAGE_OPTIONS]"
            :on-page-change="onRowStatesPageChange"
            :on-items-per-page-change="onRowStatesItemsPerPageChange"
          />
        </template>
      </CardContent>
    </Card>

    <Card class="gap-0 overflow-hidden py-0" :class="progressCardBorderClass">
      <CardHeader class="border-b px-4 py-3">
        <CardTitle class="text-sm font-semibold">{{ t('admin.people.bulk_import.import.progress.title') }}</CardTitle>
      </CardHeader>
      <CardContent class="space-y-4 px-4 py-4">
        <div class="space-y-2">
          <p class="text-sm font-medium">{{ progressStatusTitle }}</p>
          <p class="text-xs text-muted-foreground">{{ progressStatusDescription }}</p>
        </div>

        <div class="space-y-2">
          <div class="flex items-center justify-between text-xs text-muted-foreground">
            <span>{{ progressPercentage }}%</span>
            <span v-if="progressCounter">{{ progressCounter }}</span>
          </div>
          <div
            class="h-2 w-full overflow-hidden rounded-full bg-muted"
            role="progressbar"
            :aria-valuenow="progressPercentage"
            aria-valuemin="0"
            aria-valuemax="100"
          >
            <div
              class="h-full rounded-full bg-primary transition-all duration-500 ease-out"
              :style="{ width: `${progressPercentage}%` }"
            />
          </div>
        </div>

        <ul
          v-if="displayLogs.length > 0"
          class="max-h-48 space-y-2 overflow-y-auto rounded-md border bg-muted/20 p-3"
        >
          <li
            v-for="(log, index) in displayLogs"
            :key="`${log.rowNumber}-${log.createdAt ?? index}`"
            class="flex items-start justify-between gap-3 text-sm"
          >
            <div class="flex min-w-0 items-start gap-2">
              <component :is="logIcon(log.status)" class="mt-0.5 size-4 shrink-0" :class="logIconClass(log.status)" aria-hidden="true" />
              <span class="min-w-0">
                {{ t('admin.people.bulk_import.import.progress.log_line', { row: log.rowNumber, message: log.message }) }}
              </span>
            </div>
            <span class="shrink-0 text-xs tabular-nums text-muted-foreground">{{ formatLogTime(log.createdAt) }}</span>
          </li>
        </ul>
      </CardContent>
    </Card>
  </div>
</template>

<script setup lang="ts">
import { computed, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { toast } from 'vue-sonner'
import { AlertTriangle, CheckCircle2, CircleAlert, CircleCheck, Copy, Send, UserPlus } from 'lucide-vue-next'
import DataTablePagination from '@/components/admin/table/DataTablePagination.vue'
import ListItem from '@/components/custom/list/ListItem.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Checkbox } from '@/components/ui/checkbox'
import { Skeleton } from '@/components/ui/skeleton'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { BULK_IMPORT_PREVIEW_PER_PAGE_OPTIONS } from '@/lib/constants/bulk_import'
import { useBulkPeoplePreviewRows } from '@/lib/composables/bulk_people/useBulkPeoplePreviewRows'
import { useBulkUnitsPreviewRowsQuery } from '@/lib/composables/bulk_units/useBulkUnitsPreviewRows'
import { useTriggerRowInvitations } from '@/lib/composables/bulk_people/useTriggerRowInvitations'
import type {
  BulkImportImportLog,
  BulkImportImportLogStatus,
  BulkImportImportPhase,
  BulkImportImportProgress,
  BulkImportImportSummary,
  BulkImportOnboardingClassification,
  BulkImportRowRecord,
  BulkImportTriggerInvitationsResult,
} from '@/types/bulk_import'

const props = defineProps<{
  bulkImportId: string | null
  summary: BulkImportImportSummary | null
  phase: BulkImportImportPhase
  importValidRowsOnly: boolean
  progress: BulkImportImportProgress | null
  logs: BulkImportImportLog[]
  hasPendingIssues: boolean
  formatLogTime: (iso?: string) => string
}>()

const emit = defineEmits<{
  'update:importValidRowsOnly': [value: boolean]
}>()

const { t } = useI18n()

const isProcessing = computed(() => props.phase === 'processing')
const isCompleted = computed(() => props.phase === 'completed')
const isFailed = computed(() => props.phase === 'failed')

const {
  rows: rowStates,
  summary: rowStatesSummary,
  pagination,
  isLoadingRows,
  fetchRows,
} = useBulkPeoplePreviewRows(() => props.bulkImportId)

const { onPageChange: onRowStatesPageChange, onItemsPerPageChange: onRowStatesItemsPerPageChange } =
  useBulkUnitsPreviewRowsQuery(() => 'all', () => '', fetchRows)

watch(
  isCompleted,
  (completed) => {
    if (completed) void fetchRows({ page: 1 })
  },
  { immediate: true },
)

const { isTriggering, triggerInvitations } = useTriggerRowInvitations(() => props.bulkImportId)

const hasPendingTriggerableRows = computed(() => {
  const current = rowStatesSummary.value
  if (!current) return false
  return (current.pending_invitation_rows ?? 0) + (current.pending_incorporation_rows ?? 0) > 0
})

const TRIGGERABLE_CLASSIFICATIONS: BulkImportOnboardingClassification[] = [
  'requires_invitation',
  'requires_incorporation',
]

function isTriggerable(row: BulkImportRowRecord) {
  return (
    row.onboarding_classification !== null &&
    TRIGGERABLE_CLASSIFICATIONS.includes(row.onboarding_classification) &&
    row.target_record_type !== 'OnboardingRequest'
  )
}

function isTriggered(row: BulkImportRowRecord) {
  return (
    row.onboarding_classification !== null &&
    TRIGGERABLE_CLASSIFICATIONS.includes(row.onboarding_classification) &&
    row.target_record_type === 'OnboardingRequest'
  )
}

async function triggerOne(row: BulkImportRowRecord) {
  const result = await triggerInvitations([ row.id ])
  handleTriggerResult(result)
}

async function triggerAll() {
  const result = await triggerInvitations()
  handleTriggerResult(result)
}

function handleTriggerResult(result: BulkImportTriggerInvitationsResult | null) {
  if (!result) {
    toast.error(t('admin.people.bulk_import.import.row_states.actions.trigger_error'))
    return
  }

  toast.success(
    t('admin.people.bulk_import.import.row_states.actions.trigger_success', {
      triggered: result.counts.triggered,
      conflicted: result.counts.conflicted,
      skipped: result.counts.skipped,
      failed: result.counts.failed,
    }),
  )
  void fetchRows({ page: pagination.value.current_page })
}

function formatClassification(classification: BulkImportOnboardingClassification | null) {
  if (!classification) return '—'
  const key = `admin.people.bulk_import.import.row_states.classifications.${classification}`
  const translated = t(key)
  return translated === key ? classification : translated
}

function classificationBadgeVariant(classification: BulkImportOnboardingClassification | null) {
  if (classification === 'ready_to_create_person') return 'success'
  if (classification === 'conflict' || classification === 'invalid') return 'destructive'
  if (classification === 'duplicate') return 'secondary'
  return 'outline'
}

const summaryStatCards = computed(() => {
  const current = props.summary
  return [
    {
      key: 'new',
      label: t('admin.people.bulk_import.import.ready.stats.new_people'),
      value: current?.newUnits ?? 0,
      icon: UserPlus,
      iconClass: 'text-green-600',
    },
    {
      key: 'duplicates',
      label: t('admin.people.bulk_import.import.ready.stats.duplicates'),
      value: current?.duplicateRows ?? 0,
      icon: Copy,
      iconClass: 'text-amber-600',
    },
    {
      key: 'errors',
      label: t('admin.people.bulk_import.import.ready.stats.errors'),
      value: current?.errorRows ?? 0,
      icon: AlertTriangle,
      iconClass: 'text-destructive',
    },
  ]
})

const progressPercentage = computed(() => {
  if (isCompleted.value) return 100
  return props.progress?.percentage ?? 0
})

const progressCounter = computed(() => {
  if (!props.progress || props.progress.total === 0) return null
  return t('admin.people.bulk_import.import.progress.counter', {
    processed: props.progress.created,
    total: props.progress.total,
  })
})

const progressStatusTitle = computed(() => {
  if (isCompleted.value) return t('admin.people.bulk_import.import.progress.completed.title')
  if (isFailed.value) return t('admin.people.bulk_import.import.progress.failed.title')
  if (isProcessing.value) return t('admin.people.bulk_import.import.progress.processing.title')
  return t('admin.people.bulk_import.import.progress.waiting.title')
})

const progressStatusDescription = computed(() => {
  if (isCompleted.value) {
    return t('admin.people.bulk_import.import.progress.completed.description', {
      created: props.progress?.created ?? 0,
      skipped: props.progress?.skipped ?? 0,
      failed: props.progress?.failed ?? 0,
    })
  }
  if (isFailed.value) return t('admin.people.bulk_import.import.progress.failed.description')
  if (isProcessing.value) return t('admin.people.bulk_import.import.progress.processing.description')
  return t('admin.people.bulk_import.import.progress.waiting.description')
})

const progressCardBorderClass = computed(() => {
  if (isProcessing.value) return 'border-primary/40'
  if (isCompleted.value) return 'border-green-200 dark:border-green-900'
  if (isFailed.value) return 'border-destructive/40'
  return ''
})

const displayLogs = computed(() => props.logs.slice(0, 15))

function logIcon(status: BulkImportImportLogStatus) {
  if (status === 'success') return CircleCheck
  if (status === 'warning') return AlertTriangle
  return CircleAlert
}

function logIconClass(status: BulkImportImportLogStatus) {
  if (status === 'success') return 'text-green-600'
  if (status === 'warning') return 'text-amber-600'
  return 'text-destructive'
}
</script>
