<template>
  <Card>
    <CardHeader>
      <CardTitle>{{ t('admin.visits.show.history.title') }}</CardTitle>
      <CardDescription>{{ t('admin.visits.show.history.description') }}</CardDescription>
    </CardHeader>
    <CardContent>
      <Timeline
        :entries="timelineEntries"
        :empty-title="t('admin.visits.show.history.empty')"
        :locale="locale"
      />
    </CardContent>
  </Card>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import Timeline from '@/components/admin/shared/Timeline.vue'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { historyToTimelineEntries } from '@/lib/utils/visit_detail'
import type { VisitHistoryEntry } from '@/types/visit'

const props = defineProps<{
  history?: VisitHistoryEntry[]
  locale: string
}>()

const { t } = useI18n()

const timelineEntries = computed(() => historyToTimelineEntries(props.history))
</script>
