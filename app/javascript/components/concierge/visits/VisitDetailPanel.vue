<template>
  <div class="space-y-6">
    <VisitOperationalSummary :visit="visit" />

    <Card>
      <CardHeader>
        <CardTitle class="text-base">{{ t('concierge.visits.show.sections.details') }}</CardTitle>
      </CardHeader>
      <CardContent class="grid gap-4 sm:grid-cols-2">
        <div>
          <p class="text-muted-foreground text-xs">{{ t('concierge.visits.show.fields.scheduled_at') }}</p>
          <p class="font-medium">{{ formatDateTime(visit.scheduled_at) }}</p>
        </div>
        <div>
          <p class="text-muted-foreground text-xs">{{ t('concierge.visits.show.fields.valid_until') }}</p>
          <p class="font-medium">{{ formatDateTime(visit.valid_until) }}</p>
        </div>
        <div>
          <p class="text-muted-foreground text-xs">{{ t('concierge.visits.show.fields.authorized_at') }}</p>
          <p class="font-medium">{{ formatDateTime(visit.authorized_at) }}</p>
        </div>
        <div v-if="visit.authorized_by_name">
          <p class="text-muted-foreground text-xs">{{ t('concierge.visits.show.fields.authorized_by') }}</p>
          <p class="font-medium">{{ visit.authorized_by_name }}</p>
        </div>
        <div v-if="visit.checked_in_at">
          <p class="text-muted-foreground text-xs">{{ t('concierge.visits.show.fields.checked_in_at') }}</p>
          <p class="font-medium">{{ formatDateTime(visit.checked_in_at) }}</p>
        </div>
        <div v-if="visit.checked_in_by_name">
          <p class="text-muted-foreground text-xs">{{ t('concierge.visits.show.fields.checked_in_by') }}</p>
          <p class="font-medium">{{ visit.checked_in_by_name }}</p>
        </div>
        <div v-if="visit.checked_out_at">
          <p class="text-muted-foreground text-xs">{{ t('concierge.visits.show.fields.checked_out_at') }}</p>
          <p class="font-medium">{{ formatDateTime(visit.checked_out_at) }}</p>
        </div>
        <div v-if="visit.checked_out_by_name">
          <p class="text-muted-foreground text-xs">{{ t('concierge.visits.show.fields.checked_out_by') }}</p>
          <p class="font-medium">{{ visit.checked_out_by_name }}</p>
        </div>
        <div v-if="durationLabel">
          <p class="text-muted-foreground text-xs">{{ durationFieldLabel }}</p>
          <p class="font-medium">{{ durationLabel }}</p>
        </div>
      </CardContent>
    </Card>

    <Card>
      <CardHeader>
        <CardTitle class="text-base">{{ t('concierge.visits.show.sections.timeline') }}</CardTitle>
      </CardHeader>
      <CardContent>
        <Timeline
          :entries="timelineEntries"
          :empty-title="t('concierge.visits.check_out.timeline.empty')"
          :locale="locale"
        />
      </CardContent>
    </Card>

    <div
      v-if="showExpiredInstruction"
      class="rounded-lg border border-dashed px-4 py-3 text-sm"
      role="note"
    >
      {{ t('concierge.visits.instructions.request_new_authorization') }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import Timeline from '@/components/admin/shared/Timeline.vue'
import VisitOperationalSummary from '@/components/concierge/visits/VisitOperationalSummary.vue'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { formatVisitDuration, visitEffectiveStatus } from '@/lib/utils/visit'
import type { ConciergeVisitSummary, VisitTimelineEntry } from '@/types/visit'

const props = defineProps<{
  visit: ConciergeVisitSummary
}>()

const { t, locale } = useI18n()

const showExpiredInstruction = computed(() => visitEffectiveStatus(props.visit) === 'expired')

const durationLabel = computed(() => {
  if (props.visit.duration_seconds != null && props.visit.duration_seconds >= 0) {
    return formatVisitDuration(props.visit.duration_seconds)
  }

  if (props.visit.checked_in_at && !props.visit.checked_out_at) {
    const checkedInAt = new Date(props.visit.checked_in_at).getTime()
    if (Number.isNaN(checkedInAt)) return null
    const seconds = Math.max(0, Math.floor((Date.now() - checkedInAt) / 1000))
    return formatVisitDuration(seconds)
  }

  return null
})

const durationFieldLabel = computed(() =>
  props.visit.checked_out_at
    ? t('concierge.visits.show.fields.duration')
    : t('concierge.visits.show.fields.current_duration'),
)

const timelineEntries = computed(() => {
  if (props.visit.operational_timeline?.length) {
    return props.visit.operational_timeline.map((entry) => ({
      id: entry.id,
      occurred_at: entry.occurred_at,
      description: entry.event_type_label,
      actor_name: entry.actor_name ?? '—',
      tone: entry.tone,
    }))
  }

  return buildFallbackTimeline(props.visit)
})

function buildFallbackTimeline(visit: ConciergeVisitSummary) {
  const entries: VisitTimelineEntry[] = []

  if (visit.authorized_at) {
    entries.push({
      id: 'authorized-fallback',
      event_type: 'authorized',
      event_type_label: t('concierge.visits.timeline.events.authorized'),
      occurred_at: visit.authorized_at,
      actor_name: visit.authorized_by_name ?? '—',
      tone: 'neutral',
    })
  }

  if (visit.checked_in_at) {
    entries.push({
      id: 'checked-in-fallback',
      event_type: 'checked_in',
      event_type_label: t('concierge.visits.timeline.events.checked_in'),
      occurred_at: visit.checked_in_at,
      actor_name: visit.checked_in_by_name ?? '—',
      tone: 'success',
    })
  }

  if (visit.checked_out_at) {
    entries.push({
      id: 'checked-out-fallback',
      event_type: 'checked_out',
      event_type_label: t('concierge.visits.timeline.events.checked_out'),
      occurred_at: visit.checked_out_at,
      actor_name: visit.checked_out_by_name ?? '—',
      tone: 'neutral',
    })
  }

  return entries.map((entry) => ({
    id: entry.id,
    occurred_at: entry.occurred_at,
    description: entry.event_type_label,
    actor_name: entry.actor_name ?? '—',
    tone: entry.tone,
  }))
}

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
