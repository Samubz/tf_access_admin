<template>
  <aside class="rounded-xl border bg-muted/30 p-4">
    <div class="mb-4 space-y-1">
      <h3 class="text-sm font-semibold">{{ t('admin.visits.new.summary.title') }}</h3>
      <p class="text-xs text-muted-foreground">{{ t('admin.visits.new.summary.description') }}</p>
    </div>

    <dl class="space-y-3 text-sm">
      <div class="flex justify-between gap-3">
        <dt class="text-muted-foreground">{{ t('admin.visits.new.summary.fields.property') }}</dt>
        <dd class="text-right font-medium">{{ propertyName ?? emptyLabel }}</dd>
      </div>
      <div class="flex justify-between gap-3">
        <dt class="text-muted-foreground">{{ t('admin.visits.new.summary.fields.unit') }}</dt>
        <dd class="text-right font-medium">{{ unitLabel ?? emptyLabel }}</dd>
      </div>
      <div class="flex justify-between gap-3">
        <dt class="text-muted-foreground">{{ t('admin.visits.new.summary.fields.visitor') }}</dt>
        <dd class="text-right font-medium">{{ visitorName ?? emptyLabel }}</dd>
      </div>
      <div class="flex justify-between gap-3">
        <dt class="text-muted-foreground">{{ t('admin.visits.new.summary.fields.reason') }}</dt>
        <dd class="text-right font-medium">{{ reasonLabel ?? emptyLabel }}</dd>
      </div>
      <div class="flex justify-between gap-3">
        <dt class="text-muted-foreground">{{ t('admin.visits.new.summary.fields.schedule') }}</dt>
        <dd class="text-right font-medium">{{ scheduleLabel ?? emptyLabel }}</dd>
      </div>
      <div v-if="vehicleLabel" class="flex justify-between gap-3">
        <dt class="text-muted-foreground">{{ t('admin.visits.new.summary.fields.vehicle') }}</dt>
        <dd class="text-right font-medium">{{ vehicleLabel }}</dd>
      </div>
    </dl>

    <div
      v-if="initialStatusPreview"
      class="mt-4 rounded-lg border border-dashed bg-background p-3 text-sm"
    >
      <p class="font-medium">
        {{ t('admin.visits.new.summary.estimated_status') }}:
        {{ initialStatusPreview.initial_status_label }}
      </p>
      <p class="mt-1 text-xs text-muted-foreground">{{ initialStatusPreview.message }}</p>
    </div>
    <div v-else-if="statusLoading" class="mt-4 text-xs text-muted-foreground">
      {{ t('admin.visits.new.summary.status_loading') }}
    </div>
  </aside>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import type { VisitInitialStatusPreview, VisitTypeOption } from '@/lib/schemas/visit_create'

const props = defineProps<{
  visitTypes: VisitTypeOption[]
  propertyName?: string
  unitLabel?: string
  visitorName?: string | null
  visitType: string
  visitDate: string
  startTime: string
  endTime: string
  vehiclePlate: string
  vehicleBrandModel: string
  initialStatusPreview: VisitInitialStatusPreview | null
  statusLoading?: boolean
}>()

const { t } = useI18n()
const emptyLabel = computed(() => t('admin.visits.new.summary.empty'))

const reasonLabel = computed(
  () => props.visitTypes.find((type) => type.value === props.visitType)?.label,
)

const scheduleLabel = computed(() => {
  if (!props.visitDate || !props.startTime) return undefined

  const start = `${props.visitDate} ${props.startTime}`
  if (!props.endTime) return start
  return `${start} – ${props.endTime}`
})

const vehicleLabel = computed(() => {
  const parts = [props.vehiclePlate, props.vehicleBrandModel].filter(Boolean)
  return parts.length > 0 ? parts.join(' · ') : undefined
})
</script>
