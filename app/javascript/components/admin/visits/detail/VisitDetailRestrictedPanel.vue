<template>
  <div class="space-y-6">
    <Card>
      <CardContent class="grid gap-4 p-6 sm:grid-cols-2">
        <VisitDetailField :label="t('admin.visits.show.fields.unit')" :value="unitLabel" />
        <VisitDetailField :label="t('admin.visits.show.fields.authorizers')" :value="authorizersLabel" />
        <VisitDetailField :label="t('admin.visits.show.fields.status')" :value="visit.status_label" />
        <VisitDetailField :label="t('admin.visits.show.fields.authorized_at')" :value="formatDateTime(visit.authorized_at ?? visit.valid_from)" />
        <VisitDetailField :label="t('admin.visits.show.fields.checked_in_at')" :value="formatDateTime(visit.checked_in_at)" />
        <VisitDetailField :label="t('admin.visits.show.fields.checked_out_at')" :value="formatDateTime(visit.checked_out_at)" />
      </CardContent>
    </Card>

    <VisitDetailHistoryTab :history="visit.history" :locale="locale" />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import VisitDetailField from '@/components/admin/visits/detail/VisitDetailField.vue'
import VisitDetailHistoryTab from '@/components/admin/visits/detail/VisitDetailHistoryTab.vue'
import { Card, CardContent } from '@/components/ui/card'
import type { AdminVisitRestrictedDetail } from '@/types/visit'

const props = defineProps<{
  visit: AdminVisitRestrictedDetail
  locale: string
}>()

const { t } = useI18n()

const unitLabel = computed(
  () => props.visit.unit?.display_name ?? props.visit.unit?.identifier ?? '—',
)

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
