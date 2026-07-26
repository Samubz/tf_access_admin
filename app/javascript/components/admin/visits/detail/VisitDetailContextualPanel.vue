<template>
  <div class="space-y-6">
    <TabNav
      v-model="activeTab"
      :tabs="tabs"
      :aria-label="t('admin.visits.show.tabs.aria_label')"
    />

    <div v-if="activeTab === 'info'" class="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>{{ t('admin.visits.show.sections.visit.title') }}</CardTitle>
        </CardHeader>
        <CardContent class="grid gap-4 sm:grid-cols-2">
          <VisitDetailField :label="t('admin.visits.show.fields.status')" :value="visit.status_label" />
          <VisitDetailField :label="t('admin.visits.show.fields.reason')" :value="visit.visit_type_label ?? '—'" />
          <VisitDetailField :label="t('admin.visits.show.fields.scheduled_at')" :value="formatDateTime(visit.scheduled_at)" />
          <VisitDetailField :label="t('admin.visits.show.fields.valid_from')" :value="formatDateTime(visit.valid_from)" />
          <VisitDetailField :label="t('admin.visits.show.fields.valid_until')" :value="formatDateTime(visit.valid_until)" />
          <VisitDetailField :label="t('admin.visits.show.fields.authorized_at')" :value="formatDateTime(visit.authorized_at)" />
          <VisitDetailField :label="t('admin.visits.show.fields.authorizers')" :value="authorizersLabel" />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>{{ t('admin.visits.show.sections.visitor.title') }}</CardTitle>
        </CardHeader>
        <CardContent class="grid gap-4 sm:grid-cols-2">
          <VisitDetailField :label="t('admin.visits.show.fields.name')" :value="visit.visitor_detail?.display_name ?? visit.visitor?.display_name ?? '—'" />
          <VisitDetailField :label="t('admin.visits.show.fields.document')" :value="visit.visitor_detail?.document_number ?? '—'" />
          <VisitDetailField :label="t('admin.visits.show.fields.phone')" :value="visit.visitor_detail?.phone ?? '—'" />
        </CardContent>
      </Card>

      <Card v-if="hasVehicle">
        <CardHeader>
          <CardTitle>{{ t('admin.visits.show.sections.vehicle.title') }}</CardTitle>
        </CardHeader>
        <CardContent class="grid gap-4 sm:grid-cols-2">
          <VisitDetailField :label="t('admin.visits.show.fields.vehicle_plate')" :value="visit.metadata?.vehicle?.plate ?? '—'" />
          <VisitDetailField :label="t('admin.visits.show.fields.vehicle_brand_model')" :value="visit.metadata?.vehicle?.brand_model ?? '—'" />
          <VisitDetailField :label="t('admin.visits.show.fields.vehicle_color')" :value="visit.metadata?.vehicle?.color ?? '—'" />
        </CardContent>
      </Card>

      <Card v-if="visit.notes">
        <CardHeader>
          <CardTitle>{{ t('admin.visits.show.sections.notes.title') }}</CardTitle>
        </CardHeader>
        <CardContent>
          <p class="text-sm whitespace-pre-wrap">{{ visit.notes }}</p>
        </CardContent>
      </Card>
    </div>

    <VisitDetailHistoryTab v-else :history="visit.history" :locale="locale" />
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { History, Info } from 'lucide-vue-next'
import TabNav, { type TabNavItem } from '@/components/admin/shared/TabNav.vue'
import VisitDetailField from '@/components/admin/visits/detail/VisitDetailField.vue'
import VisitDetailHistoryTab from '@/components/admin/visits/detail/VisitDetailHistoryTab.vue'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import type { AdminVisitContextualDetail } from '@/types/visit'

const props = defineProps<{
  visit: AdminVisitContextualDetail
  locale: string
}>()

const { t } = useI18n()
const activeTab = ref('info')

const tabs = computed<TabNavItem[]>(() => [
  { id: 'info', label: t('admin.visits.show.tabs.info'), icon: Info },
  { id: 'history', label: t('admin.visits.show.tabs.history'), icon: History },
])

const hasVehicle = computed(() => {
  const vehicle = props.visit.metadata?.vehicle
  return Boolean(vehicle?.plate || vehicle?.brand_model || vehicle?.color)
})

const authorizersLabel = computed(() => {
  const authorizers = props.visit.authorizers ?? []
  if (authorizers.length === 0) return '—'
  return authorizers.map((authorizer) => authorizer.display_name).join(', ')
})

function formatDateTime(value: string | null | undefined) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value

  return new Intl.DateTimeFormat(props.locale, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date)
}
</script>
