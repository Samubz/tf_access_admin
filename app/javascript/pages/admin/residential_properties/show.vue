<template>
  <div class="space-y-6">
    <div class="flex items-start justify-between gap-4">
      <div class="flex items-center gap-3">
        <Header :itemsBreadcrumb="itemsBreadcrumb" :title="property.name" />
        <PropertyStatusBadge :status="property.status" />
      </div>
      <Link v-if="permissions.edit" :href="`/admin/property_setup/wizard/${property.id}`">
        <Button>
          <Pencil class="w-4 h-4" />
          {{ t('admin.residential_properties.show.actions.edit') }}
        </Button>
      </Link>
    </div>

    <div class="grid gap-3 grid-cols-2 md:grid-cols-4">
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

    <Card class="shadow-none">
      <CardHeader>
        <CardTitle class="text-base">{{ t('admin.residential_properties.show.general_info.title') }}</CardTitle>
      </CardHeader>
      <CardContent class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <div v-for="field in generalInfoFields" :key="field.key" class="space-y-1">
          <p class="text-muted-foreground text-xs">{{ field.label }}</p>
          <p class="text-sm font-medium">{{ field.value }}</p>
        </div>
      </CardContent>
    </Card>

    <PropertyDetailStructureMap
      v-if="hasSections"
      :tree="structureTree"
      :property-id="property.id"
      :can-manage-unit="permissions.manage_units"
    />

    <NextStepsGrid
      :title="t('admin.property_setup.step5.completed.next_steps.title')"
      :actions="nextStepActions"
    />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { Link } from '@inertiajs/vue3'
import { useI18n } from 'vue-i18n'
import { Building2, DoorOpen, Layers, Pencil, ShieldCheck } from 'lucide-vue-next'
import Header from '@/components/admin/layout/Header.vue'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import PropertyStatusBadge from '@/components/admin/residential_property/PropertyStatusBadge.vue'
import PropertyDetailStructureMap from '@/components/admin/residential_property/PropertyDetailStructureMap.vue'
import NextStepsGrid from '@/components/admin/property_setup/NextStepsGrid.vue'
import { useNextStepActions } from '@/lib/composables/property_setup/useNextStepActions'
import { getResidentialPropertyDetailBreadcrumbs } from '@/lib/breadcrumbs/residential_property'
import type { DetailSectionNode } from '@/components/admin/residential_property/PropertyDetailSectionRow.vue'

type ResidentialPropertyDetailProps = {
  property: {
    id: string
    name: string
    property_type: string
    address_line?: string | null
    city?: string | null
    region?: string | null
    country?: string | null
    status: string
    created_at: string
    updated_at: string
  }
  organization: { id: string; name: string }
  preview: {
    counts: { sections: number; units: number; level_1: number; level_2: number }
    structure: { tree: DetailSectionNode[] }
  }
  permissions: { edit: boolean; manage_units: boolean }
  next_actions: string[]
}

const props = defineProps<{ residential_property: ResidentialPropertyDetailProps }>()

const { t, locale } = useI18n()

const property = computed(() => props.residential_property.property)
const permissions = computed(() => props.residential_property.permissions)
const structureTree = computed(() => props.residential_property.preview?.structure?.tree ?? [])
const hasSections = computed(() => (props.residential_property.preview?.counts?.sections ?? 0) > 0)

const itemsBreadcrumb = computed(() => getResidentialPropertyDetailBreadcrumbs(t, property.value.name))

const { nextStepActions: allNextStepActions } = useNextStepActions(
  computed(() => props.residential_property.next_actions ?? []),
  computed(() => property.value.id),
)
// The detail page never links back to itself.
const nextStepActions = computed(() => allNextStepActions.value.filter((action) => action.key !== 'property_detail'))

function formatDate(value: string) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value

  return new Intl.DateTimeFormat(locale.value, { dateStyle: 'medium' }).format(date)
}

const summaryCards = computed(() => {
  const counts = props.residential_property.preview?.counts
  const towers = counts?.level_1 ?? 0
  const floors = counts?.level_2 ?? 0
  const structureValue =
    towers > 0 || floors > 0
      ? t('admin.residential_properties.show.summary.structure_value', { towers, floors })
      : '—'

  return [
    {
      key: 'property',
      icon: Building2,
      label: t('admin.residential_properties.show.summary.property'),
      value: property.value.name,
    },
    {
      key: 'structure',
      icon: Layers,
      label: t('admin.residential_properties.show.summary.structure'),
      value: structureValue,
    },
    {
      key: 'units',
      icon: DoorOpen,
      label: t('admin.residential_properties.show.summary.units'),
      value: t('admin.residential_properties.show.summary.units_value', { count: counts?.units ?? 0 }),
    },
    {
      key: 'status',
      icon: ShieldCheck,
      label: t('admin.residential_properties.show.summary.status'),
      value: t(`admin.residential_properties.statuses.${property.value.status}`),
    },
  ]
})

const generalInfoFields = computed(() => {
  const empty = t('admin.residential_properties.show.general_info.fields.empty')
  const fields = props.residential_property.property

  return [
    {
      key: 'property_type',
      label: t('admin.residential_properties.show.general_info.fields.property_type'),
      value: t(`admin.residential_properties.property_types.${fields.property_type}`),
    },
    {
      key: 'address_line',
      label: t('admin.residential_properties.show.general_info.fields.address_line'),
      value: fields.address_line || empty,
    },
    {
      key: 'city',
      label: t('admin.residential_properties.show.general_info.fields.city'),
      value: fields.city || empty,
    },
    {
      key: 'region',
      label: t('admin.residential_properties.show.general_info.fields.region'),
      value: fields.region || empty,
    },
    {
      key: 'country',
      label: t('admin.residential_properties.show.general_info.fields.country'),
      value: fields.country || empty,
    },
    {
      key: 'organization',
      label: t('admin.residential_properties.show.general_info.fields.organization'),
      value: props.residential_property.organization.name,
    },
    {
      key: 'created_at',
      label: t('admin.residential_properties.show.general_info.fields.created_at'),
      value: formatDate(fields.created_at),
    },
    {
      key: 'updated_at',
      label: t('admin.residential_properties.show.general_info.fields.updated_at'),
      value: formatDate(fields.updated_at),
    },
  ]
})
</script>
