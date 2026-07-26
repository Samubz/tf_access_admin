<template>
  <Step5Completed
    v-if="confirmed"
    :preview="preview"
    :next-actions="nextActions"
    :property-id="propertyId"
  />
  <div v-else class="space-y-4">
      <div class="flex items-start gap-3 rounded-lg border border-green-200 bg-green-50 p-4">
        <CheckCircle2 class="mt-0.5 size-5 shrink-0 text-green-600" />
        <div>
          <p class="font-medium">{{ t('admin.property_setup.step5.ready.title') }}</p>
          <p class="text-muted-foreground mt-1 text-sm">{{ t('admin.property_setup.step5.ready.description') }}</p>
        </div>
      </div>

      <ul class="space-y-2 text-sm">
        <li v-for="item in checklist" :key="item.key" class="flex items-center gap-2">
          <CheckCircle2 class="size-4 text-green-600" />
          <span>{{ item.label }}</span>
        </li>
      </ul>

      <section class="space-y-3">
        <h3 class="text-sm font-medium">{{ t('admin.property_setup.step5.final_summary.title') }}</h3>
        <div class="grid gap-3 sm:grid-cols-2">
          <div
            v-for="card in summaryCards"
            :key="card.key"
            class="flex items-center gap-3 rounded-lg border p-3 text-sm"
          >
            <component :is="card.icon" class="text-primary size-5 shrink-0" />
            <div>
              <p class="font-medium">{{ card.value }}</p>
              <p class="text-muted-foreground text-xs">{{ card.label }}</p>
            </div>
          </div>
        </div>
      </section>

      <label v-if="requiresAcknowledgement" class="flex items-center gap-2 text-sm">
        <Checkbox
          :model-value="ackModel"
          @update:model-value="(value: boolean | 'indeterminate') => { ackModel = value === true }"
        />
        {{ t('admin.property_setup.step5.acknowledge') }}
      </label>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { Building2, CheckCircle2, DoorOpen, Grid3x3, Layers } from 'lucide-vue-next'
import { Checkbox } from '@/components/ui/checkbox'
import Step5Completed from '@/components/admin/property_setup/Step5Completed.vue'

const props = defineProps<{
  preview: Record<string, any>
  confirmed: boolean
  nextActions: string[]
  propertyId?: string
  acknowledged: boolean
  requiresAcknowledgement?: boolean
}>()

const emit = defineEmits<{
  (e: 'update:acknowledged', value: boolean): void
}>()

const { t } = useI18n()

const ackModel = computed({
  get: () => props.acknowledged,
  set: (value: boolean) => emit('update:acknowledged', value),
})

const unitCount = computed(() => props.preview?.counts?.units ?? 0)
const towerCount = computed(() => props.preview?.counts?.level_1 ?? 0)
const floorCount = computed(() => props.preview?.counts?.level_2 ?? 0)
const structureMode = computed(() => props.preview?.structure?.mode)

const checklist = computed(() => {
  const items = [
    {
      key: 'property',
      label: t('admin.property_setup.step5.checklist.property'),
    },
  ]

  if (structureMode.value !== 'none') {
    items.push({
      key: 'structure',
      label: t('admin.property_setup.step5.checklist.structure'),
    })
  }

  items.push({
    key: 'units',
    label: t('admin.property_setup.step5.checklist.units', { count: unitCount.value }),
  })

  return items
})

const summaryCards = computed(() => [
  {
    key: 'property',
    icon: Building2,
    value: '1',
    label: t('admin.property_setup.step5.final_summary.property'),
  },
  {
    key: 'towers',
    icon: Layers,
    value: String(towerCount.value),
    label: t('admin.property_setup.step5.final_summary.towers'),
  },
  {
    key: 'floors',
    icon: Grid3x3,
    value: String(floorCount.value),
    label: t('admin.property_setup.step5.final_summary.floors'),
  },
  {
    key: 'units',
    icon: DoorOpen,
    value: String(unitCount.value),
    label: t('admin.property_setup.step5.final_summary.units'),
  },
])
</script>
