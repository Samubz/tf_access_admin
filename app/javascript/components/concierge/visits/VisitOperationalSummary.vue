<template>
  <div class="bg-muted/40 space-y-4 rounded-lg border p-4">
    <div class="flex items-start justify-between gap-3">
      <div class="flex items-center gap-3">
        <div
          class="bg-primary/10 text-primary flex size-10 shrink-0 items-center justify-center rounded-full text-sm font-semibold"
        >
          {{ initials }}
        </div>
        <div>
          <p class="font-medium">{{ visit.visitor?.display_name ?? '—' }}</p>
        </div>
      </div>
      <VisitStatusBadge :visit="visit" :status="visit.status" :label="visit.status_label" />
    </div>

    <div class="grid gap-3 sm:grid-cols-3">
      <div>
        <p class="text-muted-foreground text-xs">{{ t('concierge.visits.summary.unit') }}</p>
        <p class="text-sm font-medium">{{ unitLabel }}</p>
      </div>
      <div>
        <p class="text-muted-foreground text-xs">{{ t('concierge.visits.summary.authorizers') }}</p>
        <p class="text-sm font-medium">{{ authorizersLabel }}</p>
      </div>
      <div>
        <p class="text-muted-foreground text-xs">{{ authorizedLabel }}</p>
        <p class="text-sm font-medium">{{ authorizedTime }}</p>
      </div>
    </div>

    <div v-if="visit.checked_in_at" class="grid gap-3 sm:grid-cols-2">
      <div>
        <p class="text-muted-foreground text-xs">{{ t('concierge.visits.summary.checked_in_at') }}</p>
        <p class="text-sm font-medium">{{ formatDateTime(visit.checked_in_at) }}</p>
      </div>
      <div v-if="visit.checked_in_by_name">
        <p class="text-muted-foreground text-xs">{{ t('concierge.visits.summary.checked_in_by') }}</p>
        <p class="text-sm font-medium">{{ visit.checked_in_by_name }}</p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import VisitStatusBadge from '@/components/concierge/visits/VisitStatusBadge.vue'
import { visitAuthorizedTime, visitInitials } from '@/lib/utils/visit'
import type { ConciergeVisitListItem } from '@/types/visit'

const props = withDefaults(
  defineProps<{
    visit: ConciergeVisitListItem
    authorizedLabelKey?: string
  }>(),
  {
    authorizedLabelKey: 'concierge.visits.summary.authorized_at',
  },
)

const { t, locale } = useI18n()

const initials = computed(() => visitInitials(props.visit.visitor?.display_name))
const unitLabel = computed(
  () => props.visit.unit?.display_name ?? props.visit.unit?.identifier ?? '—',
)
const authorizedLabel = computed(() => t(props.authorizedLabelKey))
const authorizedTime = computed(() => formatDateTime(visitAuthorizedTime(props.visit)))
const authorizersLabel = computed(() => {
  const authorizers = props.visit.authorizers ?? []
  if (authorizers.length === 0) return '—'
  return authorizers.map((authorizer) => authorizer.display_name).join(', ')
})

function formatDateTime(value: string | null | undefined) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value

  return new Intl.DateTimeFormat(locale.value, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date)
}
</script>
