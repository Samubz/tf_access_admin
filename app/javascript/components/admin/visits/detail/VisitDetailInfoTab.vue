<template>
  <div class="space-y-6">
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
        <VisitDetailField :label="t('admin.visits.show.fields.checked_in_at')" :value="formatDateTime(visit.checked_in_at)" />
        <VisitDetailField :label="t('admin.visits.show.fields.checked_out_at')" :value="formatDateTime(visit.checked_out_at)" />
      </CardContent>
    </Card>

    <Card>
      <CardHeader>
        <CardTitle>{{ t('admin.visits.show.sections.visitor.title') }}</CardTitle>
      </CardHeader>
      <CardContent class="grid gap-4 sm:grid-cols-2">
        <VisitDetailField :label="t('admin.visits.show.fields.name')" :value="visit.visitor_detail?.display_name ?? '—'" />
        <VisitDetailField :label="t('admin.visits.show.fields.document')" :value="visit.visitor_detail?.document_number ?? '—'" />
        <VisitDetailField :label="t('admin.visits.show.fields.phone')" :value="visit.visitor_detail?.phone ?? '—'" />
        <VisitDetailField :label="t('admin.visits.show.fields.email')" :value="visit.visitor_detail?.email ?? '—'" />
      </CardContent>
    </Card>

    <Card>
      <CardHeader>
        <CardTitle>{{ t('admin.visits.show.sections.location.title') }}</CardTitle>
      </CardHeader>
      <CardContent class="grid gap-4 sm:grid-cols-2">
        <VisitDetailField :label="t('admin.visits.show.fields.property')" :value="visit.residential_property?.name ?? '—'" />
        <VisitDetailField
          :label="t('admin.visits.show.fields.unit')"
          :value="visit.unit?.display_name ?? visit.unit?.identifier ?? '—'"
        />
        <VisitDetailField :label="t('admin.visits.show.fields.authorizers')" :value="authorizersLabel" />
      </CardContent>
    </Card>

    <Card v-if="hasVehicle">
      <CardHeader>
        <CardTitle>{{ t('admin.visits.show.sections.vehicle.title') }}</CardTitle>
      </CardHeader>
      <CardContent class="grid gap-4 sm:grid-cols-2">
        <VisitDetailField :label="t('admin.visits.show.fields.vehicle_plate')" :value="visit.metadata?.vehicle?.plate ?? '—'" />
        <VisitDetailField :label="t('admin.visits.show.fields.vehicle_model')" :value="visit.metadata?.vehicle?.brand_model ?? '—'" />
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

    <Card>
      <CardHeader>
        <CardTitle>{{ t('admin.visits.show.sections.actors.title') }}</CardTitle>
      </CardHeader>
      <CardContent class="grid gap-4 sm:grid-cols-2">
        <VisitDetailField :label="t('admin.visits.show.fields.created_by')" :value="actorLabel(visit.created_by_actor)" />
        <VisitDetailField :label="t('admin.visits.show.fields.authorized_by')" :value="actorLabel(visit.authorized_by_actor)" />
        <VisitDetailField :label="t('admin.visits.show.fields.checked_in_by')" :value="actorLabel(visit.checked_in_by_actor)" />
        <VisitDetailField :label="t('admin.visits.show.fields.checked_out_by')" :value="actorLabel(visit.checked_out_by_actor)" />
      </CardContent>
    </Card>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import VisitDetailField from '@/components/admin/visits/detail/VisitDetailField.vue'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import type { AdminVisitDetail, VisitActor } from '@/types/visit'

const props = defineProps<{
  visit: AdminVisitDetail
  locale: string
}>()

const { t } = useI18n()

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

function actorLabel(actor: VisitActor | null | undefined) {
  return actor?.name ?? '—'
}
</script>
