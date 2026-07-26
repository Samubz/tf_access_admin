<template>
  <div class="space-y-6">
    <div class="flex items-start gap-3 rounded-lg border border-green-200 bg-green-50 p-4 text-green-900">
      <CheckCircle2 class="mt-0.5 size-5 shrink-0" />
      <div>
        <p class="font-semibold">{{ t('admin.property_setup.step5.completed.success.title') }}</p>
        <p class="mt-1 text-sm leading-relaxed">{{ t('admin.property_setup.step5.completed.success.description') }}</p>
      </div>
    </div>

    <div class="space-y-6">
        <div class="grid gap-3 grid-cols-2">
          <Card v-for="card in summaryCards" :key="card.key" class="shadow-none !p-2">
            <CardContent class="flex items-start gap-3 px-2">
              <span class="bg-muted inline-flex size-9 shrink-0 items-center justify-center rounded-full">
                <component :is="card.icon" class="text-muted-foreground size-4" />
              </span>
              <div class="min-w-0 space-y-1">
                <p class="text-muted-foreground text-xs">{{ card.label }}</p>
                <p class="text-sm leading-snug font-medium">{{ card.value }}</p>
              </div>
            </CardContent>
          </Card>
        </div>

        <NextStepsGrid
          :title="t('admin.property_setup.step5.completed.next_steps.title')"
          :actions="nextStepActions"
        />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { Building2, CheckCircle2, DoorOpen, Layers, ShieldCheck } from 'lucide-vue-next'
import { Card, CardContent } from '@/components/ui/card'
import NextStepsGrid from '@/components/admin/property_setup/NextStepsGrid.vue'
import { useNextStepActions } from '@/lib/composables/property_setup/useNextStepActions'

const props = defineProps<{
  preview: Record<string, any>
  nextActions: string[]
  propertyId?: string
}>()

const { t } = useI18n()

const propertyName = computed(() => props.preview?.property?.name || '—')
const unitCount = computed(() => props.preview?.counts?.units ?? 0)
const towerCount = computed(() => props.preview?.counts?.level_1 ?? 0)
const floorCount = computed(() => props.preview?.counts?.level_2 ?? 0)
const structureMode = computed(() => props.preview?.structure?.mode)

const structureSummary = computed(() => {
  if (towerCount.value > 0 && floorCount.value > 0) {
    return t('admin.property_setup.step5.completed.summary.structure_value', {
      towers: towerCount.value,
      floors: floorCount.value,
    })
  }

  return structureMode.value === 'none'
    ? t('admin.property_setup.step2.modes.none.title')
    : '—'
})

const summaryCards = computed(() => [
  {
    key: 'property',
    icon: Building2,
    label: t('admin.property_setup.step5.completed.summary.property'),
    value: propertyName.value,
  },
  {
    key: 'structure',
    icon: Layers,
    label: t('admin.property_setup.step5.completed.summary.structure'),
    value: structureSummary.value,
  },
  {
    key: 'units',
    icon: DoorOpen,
    label: t('admin.property_setup.step5.completed.summary.units'),
    value: t('admin.property_setup.step5.completed.summary.units_value', { count: unitCount.value }),
  },
  {
    key: 'status',
    icon: ShieldCheck,
    label: t('admin.property_setup.step5.completed.summary.status'),
    value: t('admin.property_setup.step5.completed.summary.status_value'),
  },
])

const { nextStepActions } = useNextStepActions(
  computed(() => props.nextActions),
  computed(() => props.propertyId),
)
</script>
