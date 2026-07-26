<template>
  <div class="space-y-6">

    <section class="overflow-hidden rounded-lg border">
      <header class="flex items-center justify-between gap-3 border-b px-4 py-3">
        <div class="flex items-center gap-2">
          <Building2 class="text-muted-foreground size-4 shrink-0" />
          <h3 class="text-sm font-medium">{{ t('admin.property_setup.step4.sections.property') }}</h3>
        </div>
        <Button variant="ghost" size="icon" class="size-8 shrink-0" disabled aria-hidden="true">
          <MoreHorizontal class="size-4" />
        </Button>
      </header>
      <div class="grid gap-4 p-4 sm:grid-cols-2">
        <div v-for="item in propertyDetails" :key="item.label" class="space-y-1">
          <p class="text-muted-foreground text-xs">{{ item.label }}</p>
          <p class="text-sm font-medium">{{ item.value }}</p>
        </div>
      </div>
    </section>

    <section class="overflow-hidden rounded-lg border">
      <header class="flex items-center justify-between gap-3 border-b px-4 py-3">
        <div class="flex items-center gap-2">
          <DoorOpen class="text-muted-foreground size-4 shrink-0" />
          <h3 class="text-sm font-medium">{{ t('admin.property_setup.step4.sections.units') }}</h3>
        </div>
        <Button variant="ghost" size="icon" class="size-8 shrink-0" disabled aria-hidden="true">
          <MoreHorizontal class="size-4" />
        </Button>
      </header>
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead class="bg-muted/50">
            <tr>
              <th
                v-for="column in tableColumns"
                :key="column.key"
                class="px-3 py-2 text-left font-medium whitespace-nowrap"
              >
                {{ column.label }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="unit in unitsPreview" :key="unit.id" class="border-t">
              <td class="px-3 py-2 whitespace-nowrap">{{ unit.tower_name || '—' }}</td>
              <td class="px-3 py-2 whitespace-nowrap">{{ unit.floor_name || '—' }}</td>
              <td class="px-3 py-2 whitespace-nowrap">{{ unit.identifier }}</td>
              <td class="px-3 py-2 whitespace-nowrap">{{ unitTypeLabel(unit.unit_type) }}</td>
              <td class="px-3 py-2 whitespace-nowrap">{{ unit.orientation || '—' }}</td>
              <td class="px-3 py-2 whitespace-nowrap">{{ formatArea(unit.area_m2) }}</td>
              <td class="px-3 py-2 whitespace-nowrap">{{ formatBedrooms(unit.bedrooms) }}</td>
            </tr>
            <tr v-if="!unitsPreview.length">
              <td :colspan="tableColumns.length" class="text-muted-foreground px-3 py-6 text-center">
                {{ t('admin.property_setup.step4.table.empty') }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-if="unitsTotal > 0" class="text-muted-foreground border-t px-4 py-3 text-center text-sm">
        {{ t('admin.property_setup.step4.units_total', { count: unitsTotal }) }}
      </p>
    </section>

    <div v-if="preview.blocking_errors?.length" class="space-y-1">
      <p v-for="error in preview.blocking_errors" :key="error" class="text-destructive text-sm">{{ error }}</p>
    </div>
    <div v-if="preview.warnings?.length" class="space-y-1">
      <p v-for="warning in preview.warnings" :key="warning" class="text-amber-700 text-sm">{{ warning }}</p>
    </div>
    <div v-if="preview.duplicates?.length" class="space-y-1">
      <p v-for="duplicate in preview.duplicates" :key="duplicate" class="text-amber-700 text-sm">{{ duplicate }}</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { Building2, DoorOpen, MoreHorizontal } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'

const props = defineProps<{
  preview: Record<string, any>
}>()

const { t } = useI18n()

const unitsTotal = computed(() => props.preview.counts?.units ?? 0)
const unitsPreview = computed(() => props.preview?.units ?? [])

const fullAddress = computed(() => {
  const property = props.preview.property ?? {}
  return [property.address_line, property.city, property.region]
    .filter((part) => typeof part === 'string' && part.trim().length > 0)
    .join(', ') || '—'
})


const propertyDetails = computed(() => {
  const property = props.preview.property ?? {}

  return [
    { label: t('admin.property_setup.step1.fields.name'), value: property.name || '—' },
    {
      label: t('admin.property_setup.step1.fields.property_type'),
      value: property.property_type
        ? t(`admin.residential_properties.property_types.${property.property_type}`)
        : '—',
    },
    { label: t('admin.property_setup.step1.fields.address'), value: fullAddress.value },
  ]
})

const tableColumns = computed(() => [
  { key: 'tower', label: t('admin.property_setup.step4.table.tower') },
  { key: 'floor', label: t('admin.property_setup.step4.table.floor') },
  { key: 'unit', label: t('admin.property_setup.step4.table.unit') },
  { key: 'type', label: t('admin.property_setup.step4.table.type') },
  { key: 'orientation', label: t('admin.property_setup.step4.table.orientation') },
  { key: 'area', label: t('admin.property_setup.step4.table.area') },
  { key: 'bedrooms', label: t('admin.property_setup.step4.table.bedrooms') },
])

function unitTypeLabel(type?: string) {
  if (!type) return '—'
  return t(`admin.units.unit_types.${type}`)
}

function formatArea(area?: number | string | null) {
  if (area === null || area === undefined || area === '') return '—'
  return t('admin.property_setup.step4.table.area_value', { value: area })
}

function formatBedrooms(bedrooms?: number | string | null) {
  if (bedrooms === null || bedrooms === undefined || bedrooms === '') return '—'
  return String(bedrooms)
}
</script>
